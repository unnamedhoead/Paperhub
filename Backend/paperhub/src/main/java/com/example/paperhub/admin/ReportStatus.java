package com.example.paperhub.admin;

/**
 * Unified report status shared across admin/ and report/ packages.
 * <ul>
 *   <li>{@code PENDING} — 待处理</li>
 *   <li>{@code PROCESSED} — 已处理（下架/打回等操作已执行）</li>
 *   <li>{@code IGNORED} — 已忽略</li>
 *   <li>{@code RESOLVED} — 已解决（兼容旧 admin 举报流，语义等价于 PROCESSED）</li>
 * </ul>
 */
public enum ReportStatus {
    PENDING,
    PROCESSED,
    IGNORED,
    RESOLVED
}


