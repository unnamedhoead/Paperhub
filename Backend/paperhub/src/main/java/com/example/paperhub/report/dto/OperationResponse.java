package com.example.paperhub.report.dto;

/**
 * Generic operation response used across report controllers.
 */
public record OperationResponse(
        boolean success,
        String message,
        Object data
) {}
