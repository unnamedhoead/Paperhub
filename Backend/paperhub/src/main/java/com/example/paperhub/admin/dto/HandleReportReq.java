package com.example.paperhub.admin.dto;

import jakarta.validation.constraints.NotNull;

public record HandleReportReq(
        @NotNull ReportAction action,
        String resolutionNote
) {}
