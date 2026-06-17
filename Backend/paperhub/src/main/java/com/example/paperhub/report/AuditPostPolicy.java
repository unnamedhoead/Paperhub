package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostStatus;
import org.springframework.stereotype.Component;

@Component
public class AuditPostPolicy implements PostVisibilityPolicy {

    @Override
    public PostVisibilityResult evaluate(Post post, User currentUser) {
        boolean isAuthor = currentUser != null
                && post.getAuthor().getId().equals(currentUser.getId());
        if (isAuthor) {
            return new PostVisibilityResult(true, false,
                    "审核中，请等待管理员审核");
        }
        return new PostVisibilityResult(false, false, "该帖子正在审核中");
    }

    @Override
    public PostStatus supportedStatus() {
        return PostStatus.AUDIT;
    }
}
