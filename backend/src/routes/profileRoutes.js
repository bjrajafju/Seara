import express from "express";
import {
    getProfile,
    updateProfile,
    getAllUsers,
    followUser,
    isFollowing,
    unfollowUser,
    getUsersWithRelationship,
} from "../controllers/profileController.js";

const router = express.Router();

router.get("/users", getAllUsers);
router.get("/users-with-relationship/:userId", getUsersWithRelationship);

router.get("/me", getProfile);
router.get("/:userId", getProfile);
router.put("/:userId", updateProfile);
router.post("/follow", followUser);
router.post("/unfollow", unfollowUser);
router.post("/isFollowing", isFollowing);

export default router;
