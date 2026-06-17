package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostStatus;

/**
 * Strategy interface for post visibility logic based on PostStatus.
 * Replaces the 62-line switch-case in the old getPostDetail method.
 */
public interface PostVisibilityPolicy {

    /**
     * Returns the visibility result for the given post and current user.
     */
    PostVisibilityResult evaluate(Post post, User currentUser);

    /**
     * The PostStatus this policy handles.
     */
    PostStatus supportedStatus();

    /**
     * Result of visibility evaluation.
     */
    record PostVisibilityResult(boolean visible, boolean canEdit, String message) {}
}
