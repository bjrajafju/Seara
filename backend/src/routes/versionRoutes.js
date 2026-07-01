import express from "express";

const router = express.Router();

const LATEST_VERSION = "2.0.0";
const MIN_VERSION = "1.0.0";
const ANDROID_FILE = "Seara.apk";
const ANDROID_URL = `https://github.com/bjrajafju/Seara/releases/download/${LATEST_VERSION}/${ANDROID_FILE}`;

router.get("/", (req, res) => {
    const platform = req.query.platform || "windows";

    if (platform === "android") {
        return res.json({
            latestVersion: LATEST_VERSION,
            minVersion: MIN_VERSION,
            url: ANDROID_URL,
        });
    }

    return res.json({
        latestVersion: LATEST_VERSION,
        minVersion: MIN_VERSION,
        url: "https://seara.onrender.com/download/SearaSetup.exe",
    });
});

export default router;
