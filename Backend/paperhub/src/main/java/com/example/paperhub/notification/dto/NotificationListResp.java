package com.example.paperhub.notification.dto;

import java.util.List;

public record NotificationListResp(
        List<NotificationResp> notifications,
        long total,
        int page,
        int pageSize
) {
}
