package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Resolves the correct {@link PostVisibilityPolicy} for a given PostStatus.
 * Injects all policy implementations and selects by status.
 */
@Component
public class PostVisibilityResolver {

    private final Map<com.example.paperhub.post.PostStatus, PostVisibilityPolicy> policyMap;

    public PostVisibilityResolver(List<PostVisibilityPolicy> policies) {
        this.policyMap = policies.stream()
                .collect(Collectors.toMap(
                        PostVisibilityPolicy::supportedStatus,
                        Function.identity()
                ));
    }

    public PostVisibilityPolicy.PostVisibilityResult resolve(Post post, User currentUser) {
        PostVisibilityPolicy policy = policyMap.get(post.getStatus());
        if (policy == null) {
            return new PostVisibilityPolicy.PostVisibilityResult(false, false, "未知状态");
        }
        return policy.evaluate(post, currentUser);
    }
}
