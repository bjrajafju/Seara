import express from "express";

const router = express.Router();

router.get("/", (req, res) => {
  res.json({
    latestVersion: "1.0.1",
    minVersion: "1.0.0",
    url: "http://localhost:3000/download/SearaSetup.exe"
  });
});

export default router;
