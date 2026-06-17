package com.example.paperhub.report.dto;

/**
 * Admin request to ignore a report.
 */
public record IgnoreReportRequest(
        String reason
) {}
