# Architecture

## Overview

This document defines the architecture, patterns, and conventions for the project.

---

## Core Principles

1. **Compile-Time Correctness**: Use strong typing, Result types, and discriminated unions to catch errors at compile time
2. **Security Boundaries**: Explicit authentication and authorisation layers with clear separation of concerns
3. **Testability**: Dependency injection, interface-based design, and pure functions where possible
4. **Simplicity**: Avoid over-engineering; prefer clear, maintainable code over clever abstractions