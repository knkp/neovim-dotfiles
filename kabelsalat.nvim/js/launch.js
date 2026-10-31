// Drives the Kabelsalat web REPL (https://kabel.salat.dev) from Neovim via Puppeteer.
//
// Protocol (one message per line):
//   stdin:  KS_CONTENT:<base64>  replace the REPL editor content
//           KS_UPDATE            evaluate the current code (same as ctrl+enter)
//           KS_STOP              stop playback
//           KS_TOGGLE            evaluate if stopped, stop if playing
//           KS_QUIT              close the browser
//   stdout: KS_READY             the REPL editor is loaded
//           KS_ERROR:<base64>    the REPL error message changed (empty = cleared)
//
// Puppeteer is resolved through NODE_PATH (set by the Lua side), so it can be shared with strudel.nvim.

const puppeteer = require("puppeteer");
const os = require("os");
const path = require("path");

const MESSAGES = {
    CONTENT: "KS_CONTENT:",
    UPDATE: "KS_UPDATE",
    STOP: "KS_STOP",
    TOGGLE: "KS_TOGGLE",
    QUIT: "KS_QUIT",
    READY: "KS_READY",
    ERROR: "KS_ERROR:",
};

const SELECTORS = {
    EDITOR: ".cm-content",
    // Repl.jsx renders evaluation errors in a red bar under the editor
    ERROR: ".text-red-500",
};

const config = {
    url: "https://kabel.salat.dev/",
    browserExecPath: null,
    userDataDir: path.join(os.homedir(), ".cache", "kabelsalat-nvim"),
    headless: false,
};
for (const arg of process.argv.slice(2)) {
    if (arg.startsWith("--url=")) config.url = arg.slice("--url=".length);
    else if (arg.startsWith("--browser-exec-path=")) config.browserExecPath = arg.slice("--browser-exec-path=".length);
    else if (arg.startsWith("--user-data-dir=")) config.userDataDir = arg.slice("--user-data-dir=".length);
    else if (arg === "--headless") config.headless = true;
}

let browser = null;
let page = null;
let playing = false;

// Replace the editor content with a minimal diff so the REPL's widgets/flash aren't reset needlessly
async function setContent(content) {
    await page.evaluate((newContent) => {
        const view = document.querySelector(".cm-content").cmView.view;
        const oldContent = view.state.doc.toString();
        if (oldContent === newContent) return;

        let start = 0;
        while (start < oldContent.length && start < newContent.length && oldContent[start] === newContent[start]) {
            start++;
        }
        let endOld = oldContent.length;
        let endNew = newContent.length;
        while (endOld > start && endNew > start && oldContent[endOld - 1] === newContent[endNew - 1]) {
            endOld--;
            endNew--;
        }
        view.dispatch({ changes: { from: start, to: endOld, insert: newContent.slice(start, endNew) } });
    }, content);
}

// The REPL's run() isn't exposed, so trigger it through its ctrl+enter editor keybinding
async function evaluate() {
    await page.evaluate(() => document.querySelector(".cm-content").cmView.view.focus());
    await page.keyboard.down("Control");
    await page.keyboard.press("Enter");
    await page.keyboard.up("Control");
    playing = true;
}

async function stop() {
    await page.evaluate(() => window.repl.stop());
    playing = false;
}

async function handleMessage(message) {
    if (message.startsWith(MESSAGES.CONTENT)) {
        await setContent(Buffer.from(message.slice(MESSAGES.CONTENT.length), "base64").toString("utf8"));
    } else if (message === MESSAGES.UPDATE) {
        await evaluate();
    } else if (message === MESSAGES.STOP) {
        await stop();
    } else if (message === MESSAGES.TOGGLE) {
        playing ? await stop() : await evaluate();
    } else if (message === MESSAGES.QUIT) {
        await browser.close();
        process.exit(0);
    }
}

// Process stdin messages sequentially; a single chunk may hold several lines (or part of one)
let pending = "";
let queue = Promise.resolve();
process.stdin.on("data", (data) => {
    pending += data.toString();
    const lines = pending.split("\n");
    pending = lines.pop();
    for (const line of lines) {
        const message = line.trim();
        if (!message) continue;
        queue = queue.then(() => page && handleMessage(message)).catch((err) => console.error("Error handling message:", err));
    }
});

(async () => {
    try {
        browser = await puppeteer.launch({
            headless: config.headless,
            defaultViewport: null,
            userDataDir: config.userDataDir,
            ignoreDefaultArgs: ["--mute-audio", "--enable-automation"],
            args: [`--app=${config.url}`, "--autoplay-policy=no-user-gesture-required"],
            ...(config.browserExecPath && { executablePath: config.browserExecPath }),
        });

        page = (await browser.pages())[0];
        await page.waitForSelector(SELECTORS.EDITOR, { timeout: 30000 });

        browser.on("disconnected", () => process.exit(0));
        page.on("close", () => process.exit(0));

        // Report REPL error changes back to Neovim
        await page.exposeFunction("ksNotifyError", (message) => {
            process.stdout.write(MESSAGES.ERROR + Buffer.from(message).toString("base64") + "\n");
        });
        await page.evaluate((errorSelector) => {
            let lastError = "";
            setInterval(() => {
                const error = document.querySelector(errorSelector)?.textContent.trim() ?? "";
                if (error !== lastError) {
                    lastError = error;
                    window.ksNotifyError(error);
                }
            }, 300);
        }, SELECTORS.ERROR);

        process.stdout.write(MESSAGES.READY + "\n");
    } catch (error) {
        console.error("Error:", error);
        process.exit(1);
    }
})();
