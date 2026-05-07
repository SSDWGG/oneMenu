const translations = {
    zh: {
        title: "AiStatus - macOS 菜单栏 AI 状态灯",
        description: "AiStatus 是一款 macOS 菜单栏工具，用独立状态灯显示 Codex/GPT 和 Claude Code 任务，并集中展示天气、硬件、倒计时、系统提醒和防休眠状态。",
        headerAria: "主导航",
        brandAria: "AiStatus 首页",
        navAria: "页面导航",
        navFeatures: "功能",
        navPrivacy: "隐私",
        navInstall: "安装",
        navDownload: "下载 DMG",
        languageLabel: "Switch to English",
        languageButton: "EN",
        heroEyebrow: "macOS menu bar utility",
        heroTitle: "直视AI任务状态",
        heroLede: "AiStatus 把 Codex/GPT、Claude、天气、硬件、倒计时、系统提醒和防休眠状态放进 macOS 顶部状态栏，适合长时间等待 AI 输出的本地工作流。",
        downloadActionsAria: "下载操作",
        heroDownload: "下载 macOS 版",
        heroChecksum: "查看 SHA-256",
        releaseAria: "版本信息",
        releaseVersion: "版本",
        releaseFormat: "格式",
        releaseSize: "大小",
        releaseSizeValue: "约 1.2 MB",
        productAria: "AiStatus 产品预览",
        iconAlt: "AiStatus 图标",
        panelKicker: "当前状态",
        panelState: "GPT 活跃，硬件与倒计同步展示",
        activeSessionOne: "活跃会话 1",
        idleSessionOne: "闲置会话 1",
        weatherModule: "天气",
        weatherPreview: "晴 22°C",
        hardwareModule: "硬件",
        hardwarePreview: "内存 63%",
        targetCountdown: "目标倒计",
        targetCountdownPreview: "下班 42 分",
        sleepPrevention: "防休眠",
        enabled: "已开启",
        latestEvent: "菜单栏模块",
        sampleRunningTitle: "Codex/GPT 与 Claude 使用品牌图标独立展示",
        sampleEndedTitle: "硬件状态可切换 CPU、内存、电池、温度或风扇",
        running: "运行中",
        ended: "已结束",
        configurable: "可配置",
        featuresEyebrow: "What it watches",
        featuresTitle: "不止状态灯：把等待 AI 时要看的信息放到同一条菜单栏",
        featureOneTitle: "GPT / Claude 独立状态灯",
        featureOneText: "Codex/GPT 和 Claude 各自拥有独立入口，使用品牌图形区分活跃检测状态。",
        featureOneDetail: "单击查看会话悬浮窗，双击进入对应设置；活跃和闲置会话标题都能快速扫到。",
        featureTwoTitle: "天气、硬件与防休眠",
        featureTwoText: "天气显示当前温度和图标；硬件可展示 CPU、内存、电池、热状态、温度或风扇。",
        featureTwoDetail: "硬件悬浮窗仍保留完整快照；状态栏直接展示哪项指标可以在设置里切换。",
        featureThreeTitle: "倒计时与目标倒计",
        featureThreeText: "支持秒/分钟倒计、临近提醒色，以及每天目标时间的分钟倒计。",
        featureThreeDetail: "目标倒计可以配置目标名称、过点处理、状态栏背景色、文字粗细和文字颜色。",
        featureFourTitle: "通知、邮件与系统提醒",
        featureFourText: "会话结束可发桌面通知；所有 AI 工作结束后可发邮件，也能注册单次或每日系统提醒。",
        featureFourDetail: "提醒页显示系统注册状态并支持测试提醒，方便检查 macOS 通知权限和专注模式影响。",
        privacyEyebrow: "Local first",
        privacyTitle: "本地解析，不上传会话正文。",
        privacyText: "AiStatus 只读取运行状态、会话标题和系统状态快照。它不复制完整会话正文，也不需要远程账号。天气只用经纬度请求预报；AI 状态判断都在你的 Mac 上完成。",
        privacyItemCodex: "读取 <code>~/.codex/sessions</code> 的任务事件",
        privacyItemClaude: "读取 <code>~/.claude/projects</code> 的 Claude Code 事件",
        privacyItemWeather: "天气预报只发送经纬度，不上传会话内容",
        privacyItemSleep: "防休眠功能必须由用户手动开启",
        installEyebrow: "Install",
        installTitle: "下载 DMG，拖入 Applications。",
        installStepOneTitle: "下载",
        installStepOneText: "获取当前版本的 DMG 安装包。",
        installStepOneLink: "下载 AiStatus-0.1.1.dmg",
        installStepTwoTitle: "安装",
        installStepTwoText: "打开 DMG，把 AiStatus 拖到 Applications。",
        installStepThreeTitle: "运行",
        installStepThreeText: "从 Applications 启动，菜单栏出现状态灯后即可使用。",
        securityEyebrow: "Gatekeeper",
        securityTitle: "如果提示“Apple 无法验证”，这样打开。",
        securityIntro: "当前 DMG 使用非 Apple 认证证书签名，首次打开时 macOS 可能拦截。确认你从本站下载后，可以在系统设置中手动允许。",
        securityStepOne: "看到“Apple 无法验证是否包含可能危害...”提示时，先点“完成”或关闭提示。",
        securityStepTwo: "打开“系统设置” → “隐私与安全性”。",
        securityStepThree: "滚动到“安全性”，找到 AiStatus 被阻止的提示，点击“仍要打开”。",
        securityStepFour: "输入密码或使用 Touch ID，再点击“打开”。之后即可正常启动。",
        securityVisualPrivacy: "隐私与安全性",
        securityVisualTitle: "安全性",
        securityVisualText: "“AiStatus” 已被阻止使用，因为 Apple 无法验证是否包含恶意软件。",
        securityVisualButton: "仍要打开",
        securityVisualWarning: "Apple 无法验证“AiStatus”是否包含可能危害 Mac 的恶意软件。",
        currentRelease: "Current release",
        downloadPanelText: "DMG SHA-256 校验文件随包提供，适合放到下载页一起发布。",
        downloadDmg: "下载 DMG",
        copySha: "复制 SHA-256",
        copied: "已复制",
        footerDownload: "下载"
    },
    en: {
        title: "AiStatus - macOS menu bar status for AI tasks",
        description: "AiStatus is a macOS menu bar utility with independent Codex/GPT and Claude Code indicators, plus weather, hardware, countdown, reminder, and sleep-prevention status.",
        headerAria: "Main navigation",
        brandAria: "AiStatus home",
        navAria: "Page navigation",
        navFeatures: "Features",
        navPrivacy: "Privacy",
        navInstall: "Install",
        navDownload: "Download DMG",
        languageLabel: "切换到中文",
        languageButton: "中",
        heroEyebrow: "macOS menu bar utility",
        heroTitle: "See AI task status",
        heroLede: "AiStatus puts Codex/GPT, Claude, weather, hardware, countdowns, system reminders, and sleep-prevention state into the macOS menu bar for local workflows that wait on long AI runs.",
        downloadActionsAria: "Download actions",
        heroDownload: "Download for macOS",
        heroChecksum: "View SHA-256",
        releaseAria: "Release information",
        releaseVersion: "Version",
        releaseFormat: "Format",
        releaseSize: "Size",
        releaseSizeValue: "About 1.2 MB",
        productAria: "AiStatus product preview",
        iconAlt: "AiStatus icon",
        panelKicker: "Current status",
        panelState: "GPT active; hardware and countdown visible",
        activeSessionOne: "1 active session",
        idleSessionOne: "1 idle session",
        weatherModule: "Weather",
        weatherPreview: "Sunny 22°C",
        hardwareModule: "Hardware",
        hardwarePreview: "Memory 63%",
        targetCountdown: "Target timer",
        targetCountdownPreview: "Off work 42 min",
        sleepPrevention: "Keep awake",
        enabled: "Enabled",
        latestEvent: "Menu bar modules",
        sampleRunningTitle: "Codex/GPT and Claude use separate brand icons",
        sampleEndedTitle: "Hardware can switch CPU, memory, battery, temperature, or fan",
        running: "Running",
        ended: "Ended",
        configurable: "Configurable",
        featuresEyebrow: "What it watches",
        featuresTitle: "More than status lights: keep the information you watch while AI runs in one menu bar",
        featureOneTitle: "Separate GPT / Claude lights",
        featureOneText: "Codex/GPT and Claude each get their own entry, with brand marks that make active detection easy to tell apart.",
        featureOneDetail: "Click for the session popover, double-click for that provider's settings, and scan active or idle session titles quickly.",
        featureTwoTitle: "Weather, hardware, and keep awake",
        featureTwoText: "Weather shows current temperature and icon. Hardware can show CPU, memory, battery, thermal state, temperature, or fan.",
        featureTwoDetail: "The hardware popover still keeps the full snapshot. The specific menu bar metric is configurable in settings.",
        featureThreeTitle: "Countdowns and target timers",
        featureThreeText: "Use second/minute countdowns, warning colors near the end, and daily minute countdowns to a target time.",
        featureThreeDetail: "Target timers can configure the target name, after-time behavior, menu bar background, text weight, and text color.",
        featureFourTitle: "Notifications, email, and system reminders",
        featureFourText: "Get desktop notifications when sessions finish, email when all AI work ends, and one-time or daily system reminders.",
        featureFourDetail: "The reminders view shows registration state and includes a test action for checking macOS notification permissions and Focus mode.",
        privacyEyebrow: "Local first",
        privacyTitle: "Local parsing. No transcript upload.",
        privacyText: "AiStatus only reads runtime state, session titles, and system status snapshots. It does not copy full transcripts and does not require a remote account. Weather uses coordinates only for forecasts; AI status checks happen on your Mac.",
        privacyItemCodex: "Reads task events from <code>~/.codex/sessions</code>",
        privacyItemClaude: "Reads Claude Code events from <code>~/.claude/projects</code>",
        privacyItemWeather: "Weather forecasts send coordinates only, never session content",
        privacyItemSleep: "Sleep prevention is only enabled manually by the user",
        installEyebrow: "Install",
        installTitle: "Download the DMG. Drag to Applications.",
        installStepOneTitle: "Download",
        installStepOneText: "Get the current DMG release.",
        installStepOneLink: "Download AiStatus-0.1.1.dmg",
        installStepTwoTitle: "Install",
        installStepTwoText: "Open the DMG and drag AiStatus into Applications.",
        installStepThreeTitle: "Run",
        installStepThreeText: "Launch from Applications. Use the menu bar light once it appears.",
        securityEyebrow: "Gatekeeper",
        securityTitle: "If macOS says Apple cannot verify the app, open it this way.",
        securityIntro: "This DMG is signed without an Apple-certified Developer ID certificate. macOS may block the first launch. If you downloaded it from this page, allow it manually in System Settings.",
        securityStepOne: "When the warning says Apple cannot verify whether the app may harm your Mac, click Done or close the dialog.",
        securityStepTwo: "Open System Settings -> Privacy & Security.",
        securityStepThree: "Scroll to Security, find the AiStatus blocked message, then click Open Anyway.",
        securityStepFour: "Authenticate with your password or Touch ID, then click Open. Future launches should work normally.",
        securityVisualPrivacy: "Privacy & Security",
        securityVisualTitle: "Security",
        securityVisualText: "\"AiStatus\" was blocked because Apple cannot check it for malicious software.",
        securityVisualButton: "Open Anyway",
        securityVisualWarning: "Apple cannot verify whether \"AiStatus\" contains malware that may harm your Mac.",
        currentRelease: "Current release",
        downloadPanelText: "The SHA-256 checksum ships with the DMG and can be published beside the download.",
        downloadDmg: "Download DMG",
        copySha: "Copy SHA-256",
        copied: "Copied",
        footerDownload: "Download"
    }
};

const supportedLanguages = Object.keys(translations);
const savedLanguage = localStorage.getItem("aistatus-language");
const requestedLanguage = new URLSearchParams(window.location.search).get("lang");
const initialLanguage = supportedLanguages.includes(requestedLanguage)
    ? requestedLanguage
    : supportedLanguages.includes(savedLanguage) ? savedLanguage : "zh";

function applyLanguage(language) {
    const dictionary = translations[language] || translations.zh;
    const nextLanguage = language === "zh" ? "en" : "zh";
    const metaDescription = document.querySelector('meta[name="description"]');
    const toggle = document.querySelector("[data-lang-toggle]");
    const toggleLabel = document.querySelector("[data-lang-current]");

    document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
    document.title = dictionary.title;

    if (metaDescription) {
        metaDescription.setAttribute("content", dictionary.description);
    }

    document.querySelectorAll("[data-i18n]").forEach((element) => {
        const key = element.getAttribute("data-i18n");
        if (key && dictionary[key]) {
            element.textContent = dictionary[key];
        }
    });

    document.querySelectorAll("[data-i18n-html]").forEach((element) => {
        const key = element.getAttribute("data-i18n-html");
        if (key && dictionary[key]) {
            element.innerHTML = dictionary[key];
        }
    });

    document.querySelectorAll("[data-i18n-attr]").forEach((element) => {
        const attributePairs = element.getAttribute("data-i18n-attr").split(",");
        for (const pair of attributePairs) {
            const [attribute, key] = pair.split(":").map((value) => value.trim());
            if (attribute && key && dictionary[key]) {
                element.setAttribute(attribute, dictionary[key]);
            }
        }
    });

    if (toggle) {
        toggle.setAttribute("aria-label", dictionary.languageLabel);
        toggle.setAttribute("aria-pressed", String(language === "en"));
        toggle.dataset.nextLanguage = nextLanguage;
    }

    if (toggleLabel) {
        toggleLabel.textContent = dictionary.languageButton;
    }

    localStorage.setItem("aistatus-language", language);
}

document.querySelector("[data-lang-toggle]")?.addEventListener("click", (event) => {
    const nextLanguage = event.currentTarget.dataset.nextLanguage || "en";
    applyLanguage(nextLanguage);
});

applyLanguage(initialLanguage);

const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const hasPrecisePointer = window.matchMedia("(pointer: fine)").matches;

function initCursorFollower() {
    const cursor = document.querySelector("[data-cursor]");

    if (!cursor || reduceMotion.matches || !hasPrecisePointer) {
        return;
    }

    document.documentElement.classList.add("cursor-enabled");

    const state = {
        x: window.innerWidth / 2,
        y: window.innerHeight / 2,
        vx: 0,
        vy: 0,
        targetX: window.innerWidth / 2,
        targetY: window.innerHeight / 2
    };

    window.addEventListener("pointermove", (event) => {
        state.targetX = event.clientX;
        state.targetY = event.clientY;
        document.documentElement.classList.add("cursor-ready");

        if (event.target.closest("a, button, [data-spring-card]")) {
            document.documentElement.classList.add("cursor-active");
        } else {
            document.documentElement.classList.remove("cursor-active");
        }
    }, { passive: true });

    const tick = () => {
        state.vx += (state.targetX - state.x) * 0.18;
        state.vy += (state.targetY - state.y) * 0.18;
        state.vx *= 0.68;
        state.vy *= 0.68;
        state.x += state.vx;
        state.y += state.vy;
        cursor.style.transform = `translate3d(${state.x}px, ${state.y}px, 0)`;
        window.requestAnimationFrame(tick);
    };

    tick();
}

function initSpringCards() {
    if (reduceMotion.matches || !hasPrecisePointer) {
        return;
    }

    document.querySelectorAll("[data-spring-card]").forEach((card) => {
        const state = {
            x: 0,
            y: 0,
            rx: 0,
            ry: 0,
            scale: 1,
            vx: 0,
            vy: 0,
            vrx: 0,
            vry: 0,
            vs: 0,
            tx: 0,
            ty: 0,
            trx: 0,
            try: 0,
            ts: 1
        };

        const animate = () => {
            state.vx += (state.tx - state.x) * 0.15;
            state.vy += (state.ty - state.y) * 0.15;
            state.vrx += (state.trx - state.rx) * 0.14;
            state.vry += (state.try - state.ry) * 0.14;
            state.vs += (state.ts - state.scale) * 0.18;

            state.vx *= 0.66;
            state.vy *= 0.66;
            state.vrx *= 0.66;
            state.vry *= 0.66;
            state.vs *= 0.62;

            state.x += state.vx;
            state.y += state.vy;
            state.rx += state.vrx;
            state.ry += state.vry;
            state.scale += state.vs;

            card.style.setProperty("--spring-x", `${state.x.toFixed(2)}px`);
            card.style.setProperty("--spring-y", `${state.y.toFixed(2)}px`);
            card.style.setProperty("--spring-rx", `${state.rx.toFixed(2)}deg`);
            card.style.setProperty("--spring-ry", `${state.ry.toFixed(2)}deg`);
            card.style.setProperty("--spring-scale", state.scale.toFixed(4));

            window.requestAnimationFrame(animate);
        };

        card.addEventListener("pointermove", (event) => {
            const rect = card.getBoundingClientRect();
            const px = (event.clientX - rect.left) / rect.width - 0.5;
            const py = (event.clientY - rect.top) / rect.height - 0.5;
            state.tx = px * 7;
            state.ty = py * 7;
            state.trx = py * -4.2;
            state.try = px * 4.2;
            state.ts = 1.012;
        }, { passive: true });

        card.addEventListener("pointerleave", () => {
            state.tx = 0;
            state.ty = 0;
            state.trx = 0;
            state.try = 0;
            state.ts = 1;
        });

        card.addEventListener("pointerdown", () => {
            state.ts = 0.982;
        });

        card.addEventListener("pointerup", () => {
            state.ts = 1.018;
            window.setTimeout(() => {
                state.ts = 1;
            }, 120);
        });

        animate();
    });
}

function initExpandableCards() {
    document.querySelectorAll("[data-expand-card]").forEach((card) => {
        const toggle = card.querySelector(".feature-card-toggle");

        if (!toggle) {
            return;
        }

        toggle.addEventListener("click", () => {
            const isExpanded = card.classList.toggle("is-expanded");
            toggle.setAttribute("aria-expanded", String(isExpanded));
        });
    });
}

initCursorFollower();
initSpringCards();
initExpandableCards();

const revealTargets = document.querySelectorAll(".section, .feature-card, .install-step, .download-panel, .security-help");

if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver(
        (entries) => {
            for (const entry of entries) {
                if (entry.isIntersecting) {
                    entry.target.classList.add("is-visible");
                    observer.unobserve(entry.target);
                }
            }
        },
        { threshold: 0.14 }
    );

    revealTargets.forEach((target, index) => {
        target.classList.add("reveal");
        target.style.transitionDelay = `${Math.min(index * 45, 220)}ms`;
        observer.observe(target);
    });
} else {
    revealTargets.forEach((target) => target.classList.add("is-visible"));
}

document.querySelectorAll("[data-copy-source]").forEach((button) => {
    button.addEventListener("click", async () => {
        const language = localStorage.getItem("aistatus-language") || "zh";
        const dictionary = translations[language] || translations.zh;
        const sourceID = button.getAttribute("data-copy-source");
        const source = sourceID ? document.getElementById(sourceID) : null;

        if (!source) {
            return;
        }

        const originalText = button.textContent;
        try {
            await navigator.clipboard.writeText(source.textContent.trim());
            button.textContent = dictionary.copied;
            button.classList.add("is-copied");
            window.setTimeout(() => {
                button.textContent = originalText;
                button.classList.remove("is-copied");
            }, 1800);
        } catch {
            source.focus();
        }
    });
});
