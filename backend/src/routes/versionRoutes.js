import express from "express";

const router = express.Router();

router.get("/", (req, res) => {
  res.json({
    latestVersion: "1.0.6",
    minVersion: "1.0.0",
    url: "https://seara.onrender.com/download/SearaSetup.exe"
  });
});

export default router;
