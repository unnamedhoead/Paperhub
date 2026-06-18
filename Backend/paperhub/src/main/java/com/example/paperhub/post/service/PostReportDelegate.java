package com.example.paperhub.post.service;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.report.ReportPost;
import com.example.paperhub.report.ReportPostRepository;
import com.example.paperhub.report.ReportStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Report-related operations extracted from PostService.
 * P6 will take over this functionality later.
 */
@Service
public class PostReportDelegate {

    private static final Logger log = LoggerFactory.getLogger(PostReportDelegate.class);

    private final PostRepository postRepository;
    private final ReportPostRepository reportPostRepository;

    public PostReportDelegate(PostRepository postRepository,
                              ReportPostRepository reportPostRepository) {
        this.postRepository = postRepository;
        this.reportPostRepository = reportPostRepository;
    }

    /**
     * 举报帖子
     */
    @Transactional
    public ReportPost reportPost(Long postId, String description, User reporter) {
        if (reporter == null) {
            throw new IllegalArgumentException("用户未登录");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        if (reportPostRepository.existsByReporterAndPost(reporter, post)) {
            throw new IllegalArgumentException("您已经举报过该帖子");
        }

        if (post.getAuthor().getId().equals(reporter.getId())) {
            throw new IllegalArgumentException("不能举报自己的帖子");
        }

        ReportPost report = new ReportPost();
        report.setReporter(reporter);
        report.setPost(post);
        report.setDescription(description);
        report.setStatus(ReportStatus.PENDING);
        report.setReportTime(Instant.now());

        return reportPostRepository.save(report);
    }
}
