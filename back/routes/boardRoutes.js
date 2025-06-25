    const express = require("express");
    const router = express.Router();
    const boardController = require("../controllers/boardController");
    
    router.get("/", boardController.getPosts);  // ✅ 모든 게시글 & 특정 게시판 조회 합침

    // 특정 게시판 글 가져오기
    //router.get("/:boardId", boardController.getPostsByBoard);
    // 모든 게시글 가져오기
    //router.get("/", boardController.getAllPosts);
    // 게시글 작성
    router.post("/", boardController.createPost);

    // 게시글 삭제
    router.delete("/:postId", boardController.deletePost);

    // 게시글 수정 (PUT 요청)
    router.put("/:postId", boardController.updatePost);

    // ✅ 좋아요 싫어요
    router.post("/:postId/reaction", boardController.updateReaction);
    

    router.get("/posts/:postId", boardController.getPostDetails);

    //router.post("/posts/:postId/comments", boardController.createComment);
    router.post("/:postId/comments", boardController.createComment);



    module.exports = router;
