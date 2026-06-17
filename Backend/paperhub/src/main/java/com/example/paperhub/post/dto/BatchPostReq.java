package com.example.paperhub.post.dto;

import java.util.List;

/**
 * Request for batch post retrieval via GET /posts/batch?ids=1,2,3
 */
public record BatchPostReq(List<Long> ids) {
    public BatchPostReq {
        if (ids == null || ids.isEmpty()) {
            throw new IllegalArgumentException("ids must not be empty");
        }
    }
}
