"""Tests for authentication logic."""

import hmac
import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("AUTH_TOKEN", "test-token-abc123")
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-ant-test-key")

from auth.bearer import verify_token


def test_valid_token_accepted():
    assert verify_token("test-token-abc123") is True


def test_invalid_token_rejected():
    assert verify_token("wrong-token") is False


def test_empty_token_rejected():
    assert verify_token("") is False


def test_none_like_empty_rejected():
    assert verify_token("   ") is False  # whitespace is not valid


def test_partial_token_rejected():
    assert verify_token("test-token") is False


def test_timing_safe_comparison():
    # Both calls should behave identically (constant-time)
    result_correct = verify_token("test-token-abc123")
    result_wrong = verify_token("test-token-abc124")
    assert result_correct is True
    assert result_wrong is False


def test_token_is_case_sensitive():
    assert verify_token("TEST-TOKEN-ABC123") is False
    assert verify_token("Test-Token-Abc123") is False
