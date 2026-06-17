package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostStatus;
import org.springframework.stereotype.Component;

@Component
public class NormalPostPolicy implements PostVisibilityPolicy {

    @Override
    public PostVisibilityResult evaluate(Post post, User currentUser) {
        boolean isAuthor = currentUser != null
                && post.getAuthor().getId().equals(currentUser.getId());
        return new PostVisibilityResult(true, isAuthor, "正常");
    }

    @Override
    public PostStatus supportedStatus() {
        return PostStatus.NORMAL;
    }
}
