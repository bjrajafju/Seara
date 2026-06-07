import express from "express";

const router = express.Router();

router.get("/", (req, res) => {
  res.json({
    latestVersion: "1.0.3",
    minVersion: "1.0.0",
    url: "https://seara.onrender.com/download/seara.exe"
  });
});

export default router;
