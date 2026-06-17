package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostStatus;
import org.springframework.stereotype.Component;

@Component
public class DraftPostPolicy implements PostVisibilityPolicy {

    @Override
    public PostVisibilityResult evaluate(Post post, User currentUser) {
        boolean isAuthor = currentUser != null
                && post.getAuthor().getId().equals(currentUser.getId());
        if (isAuthor) {
            if (post.getUpdatedByAdmin() != null && post.getHiddenReason() != null) {
                return new PostVisibilityResult(true, true,
                        "该帖子已被管理员打回，原因：" + post.getHiddenReason()
                                + "。您可以修改后重新提交审核。");
            }
            return new PostVisibilityResult(true, true, "草稿状态，可继续编辑");
        }
        return new PostVisibilityResult(false, false, "该帖子不存在或已被删除");
    }

    @Override
    public PostStatus supportedStatus() {
        return PostStatus.DRAFT;
    }
}
