import express from "express";

const router = express.Router();

router.get("/", (req, res) => {
    const now = new Date();
    res.json({
        serverTime: now.toISOString(),
        serverDate: now.toISOString().split("T")[0]
    });
});

export default router;
