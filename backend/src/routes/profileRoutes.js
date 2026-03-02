import express from "express";
import {
    getProfile,
    updateProfile,
    getAllUsers,
    followUser,
    isFollowing,
    unfollowUser,
} from "../controllers/profileController.js";

const router = express.Router();

// temporário para fazer o perfil de outro utilizador:
router.get("/users", getAllUsers);

router.get("/me", getProfile);
router.get("/:userId", getProfile);
router.put("/:userId", updateProfile);
router.post("/follow", followUser);
router.post("/unfollow", unfollowUser);
router.post("/isFollowing", isFollowing);

export default router;
