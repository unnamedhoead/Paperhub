package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostStatus;
import org.springframework.stereotype.Component;

@Component
public class RemovedPostPolicy implements PostVisibilityPolicy {

    @Override
    public PostVisibilityResult evaluate(Post post, User currentUser) {
        boolean isAuthor = currentUser != null
                && post.getAuthor().getId().equals(currentUser.getId());
        if (isAuthor) {
            return new PostVisibilityResult(true, true,
                    "该帖子已被下架，原因："
                            + (post.getHiddenReason() != null ? post.getHiddenReason() : "违规内容")
                            + "。您可以修改后重新提交审核。");
        }
        return new PostVisibilityResult(false, false, "该帖子已被下架");
    }

    @Override
    public PostStatus supportedStatus() {
        return PostStatus.REMOVED;
    }
}
