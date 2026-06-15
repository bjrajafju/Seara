import express from "express";

const router = express.Router();

router.get("/", (req, res) => {
    const platform = req.query.platform || "windows";

    if (platform === "android") {
        return res.json({
            latestVersion: "1.3.0",
            minVersion: "1.0.0",
            url: "https://seara.onrender.com/download/Seara.apk",
        });
    }

    return res.json({
        latestVersion: "1.3.0",
        minVersion: "1.0.0",
        url: "https://seara.onrender.com/download/SearaSetup.exe",
    });
});

export default router;
