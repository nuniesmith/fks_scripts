#!/usr/bin/env python3
"""
Test script for authentication flow with UserProfile model.

This script tests:
1. fks_auth login endpoint
2. JWT token validation
3. UserProfile creation/update on login
4. App data linking to UserProfile

Usage:
    python test_authentication_flow.py [--username USERNAME] [--password PASSWORD]
"""

import os
import sys
import json
import requests
import argparse
from typing import Dict, Optional, Any

# Add Django project to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../services/web/src'))

# Set Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'settings')

import django
django.setup()

from django.contrib.auth import authenticate
from authentication.models import UserProfile
from portfolio.models import PortfolioAccount, RiskProfile
from trading.models import Signal
from authentication.api_keys import APIKey


class Colors:
    """ANSI color codes for terminal output."""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def print_success(message: str):
    """Print success message."""
    print(f"{Colors.GREEN}✓{Colors.RESET} {message}")


def print_error(message: str):
    """Print error message."""
    print(f"{Colors.RED}✗{Colors.RESET} {message}")


def print_info(message: str):
    """Print info message."""
    print(f"{Colors.BLUE}ℹ{Colors.RESET} {message}")


def print_warning(message: str):
    """Print warning message."""
    print(f"{Colors.YELLOW}⚠{Colors.RESET} {message}")


def test_fks_auth_login(username: str, password: str) -> Optional[Dict[str, Any]]:
    """
    Test fks_auth login endpoint.
    
    Returns:
        Dict with access_token, refresh_token, and user info if successful, None otherwise
    """
    print_info(f"Testing fks_auth login endpoint for user: {username}")
    
    fks_auth_url = os.getenv("FKS_AUTH_URL", "http://localhost:8009")
    login_url = f"{fks_auth_url}/login"
    
    try:
        response = requests.post(
            login_url,
            json={"username": username, "password": password},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            print_success(f"Login successful! Received JWT token")
            print(f"  Access Token: {data.get('access_token', 'N/A')[:50]}...")
            print(f"  User ID: {data.get('user', {}).get('id', 'N/A')}")
            print(f"  Username: {data.get('user', {}).get('username', 'N/A')}")
            return data
        else:
            print_error(f"Login failed: {response.status_code}")
            print(f"  Response: {response.text}")
            return None
            
    except requests.exceptions.ConnectionError:
        print_warning(f"Could not connect to fks_auth at {fks_auth_url}")
        print_warning("This is expected if fks_auth is not running or accessible")
        return None
    except Exception as e:
        print_error(f"Error during login: {e}")
        return None


def test_jwt_validation(token: str) -> bool:
    """
    Test JWT token validation endpoint.
    
    Returns:
        True if token is valid, False otherwise
    """
    print_info("Testing JWT token validation")
    
    fks_auth_url = os.getenv("FKS_AUTH_URL", "http://localhost:8009")
    verify_url = f"{fks_auth_url}/verify"
    
    try:
        response = requests.get(
            verify_url,
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        )
        
        if response.status_code == 200:
            print_success("Token validation successful!")
            return True
        else:
            print_error(f"Token validation failed: {response.status_code}")
            return False
            
    except requests.exceptions.ConnectionError:
        print_warning("Could not connect to fks_auth for token validation")
        return False
    except Exception as e:
        print_error(f"Error during token validation: {e}")
        return False


def test_django_authentication(username: str, password: str) -> Optional[Any]:
    """
    Test Django authentication with FKSAuthBackend.
    
    Returns:
        Django User object if successful, None otherwise
    """
    print_info(f"Testing Django authentication with FKSAuthBackend for: {username}")
    
    # Create a mock request object
    class MockRequest:
        def __init__(self):
            self.session = {}
    
    request = MockRequest()
    
    try:
        user = authenticate(request=request, username=username, password=password)
        
        if user:
            print_success(f"Django authentication successful!")
            print(f"  User ID: {user.id}")
            print(f"  Username: {user.username}")
            print(f"  Email: {user.email}")
            print(f"  Session user_profile_id: {request.session.get('user_profile_id', 'N/A')}")
            print(f"  Session auth_user_id: {request.session.get('auth_user_id', 'N/A')}")
            return user
        else:
            print_error("Django authentication failed")
            return None
            
    except Exception as e:
        print_error(f"Error during Django authentication: {e}")
        import traceback
        traceback.print_exc()
        return None


def test_userprofile_creation(username: str) -> bool:
    """
    Test that UserProfile exists for the user.
    
    Returns:
        True if UserProfile exists, False otherwise
    """
    print_info(f"Checking UserProfile for user: {username}")
    
    try:
        profile = UserProfile.objects.get(username=username)
        print_success(f"UserProfile found!")
        print(f"  Profile ID: {profile.id}")
        print(f"  Auth User ID: {profile.auth_user_id}")
        print(f"  Username: {profile.username}")
        print(f"  Email: {profile.email}")
        print(f"  Display Name: {profile.display_name}")
        print(f"  Role: {profile.role}")
        print(f"  Last Login: {profile.last_login}")
        return True
        
    except UserProfile.DoesNotExist:
        print_error(f"UserProfile not found for username: {username}")
        print_info("Available UserProfiles:")
        for p in UserProfile.objects.all()[:5]:
            print(f"  - {p.username} ({p.auth_user_id})")
        return False
    except UserProfile.MultipleObjectsReturned:
        profiles = UserProfile.objects.filter(username=username)
        print_warning(f"Multiple UserProfiles found for {username}: {profiles.count()}")
        for p in profiles:
            print(f"  - Profile ID {p.id}: {p.auth_user_id}")
        return True  # At least one exists
    except Exception as e:
        print_error(f"Error checking UserProfile: {e}")
        return False


def test_app_data_linking(username: str) -> Dict[str, bool]:
    """
    Test that app data (PortfolioAccount, RiskProfile, Signal, APIKey) links to UserProfile.
    
    Returns:
        Dict with test results for each model
    """
    print_info(f"Testing app data linking to UserProfile for: {username}")
    
    results = {}
    
    try:
        profile = UserProfile.objects.get(username=username)
        
        # Test PortfolioAccount
        portfolio_accounts = PortfolioAccount.objects.filter(user=profile)
        results['portfolio_accounts'] = True
        print_success(f"PortfolioAccount linking: {portfolio_accounts.count()} accounts found")
        
        # Test RiskProfile
        try:
            risk_profile = RiskProfile.objects.get(user=profile)
            results['risk_profile'] = True
            print_success(f"RiskProfile linking: Found risk profile")
        except RiskProfile.DoesNotExist:
            results['risk_profile'] = False
            print_warning("RiskProfile not found (this is OK if not created yet)")
        
        # Test Signal
        signals = Signal.objects.filter(approved_by=profile)
        results['signals'] = True
        print_success(f"Signal linking: {signals.count()} signals found")
        
        # Test APIKey
        api_keys = APIKey.objects.filter(assigned_to=profile)
        results['api_keys'] = True
        print_success(f"APIKey linking: {api_keys.count()} API keys found")
        
    except UserProfile.DoesNotExist:
        print_error(f"UserProfile not found for {username}")
        results = {'error': True}
    except Exception as e:
        print_error(f"Error testing app data linking: {e}")
        results = {'error': True}
    
    return results


def main():
    """Main test function."""
    parser = argparse.ArgumentParser(description='Test authentication flow with UserProfile')
    parser.add_argument('--username', default='testuser', help='Username to test')
    parser.add_argument('--password', default='testpass', help='Password to test')
    parser.add_argument('--skip-fks-auth', action='store_true', help='Skip fks_auth tests (if service unavailable)')
    
    args = parser.parse_args()
    
    print(f"{Colors.BOLD}=== Authentication Flow Test ==={Colors.RESET}\n")
    
    # Test 1: fks_auth login (optional)
    auth_data = None
    if not args.skip_fks_auth:
        auth_data = test_fks_auth_login(args.username, args.password)
        print()
        
        # Test 2: JWT validation (if login succeeded)
        if auth_data and auth_data.get('access_token'):
            test_jwt_validation(auth_data['access_token'])
            print()
    else:
        print_warning("Skipping fks_auth tests (--skip-fks-auth flag)")
        print()
    
    # Test 3: Django authentication
    user = test_django_authentication(args.username, args.password)
    print()
    
    if not user:
        print_error("Django authentication failed. Cannot continue with UserProfile tests.")
        print_info("Note: If fks_auth is unavailable, Django will use local auth fallback")
        return 1
    
    # Test 4: UserProfile existence
    profile_exists = test_userprofile_creation(args.username)
    print()
    
    if not profile_exists:
        print_error("UserProfile not found. Authentication may not have created it.")
        return 1
    
    # Test 5: App data linking
    linking_results = test_app_data_linking(args.username)
    print()
    
    # Summary
    print(f"{Colors.BOLD}=== Test Summary ==={Colors.RESET}")
    print_success("Django authentication: PASSED")
    print_success("UserProfile creation: PASSED")
    
    if linking_results.get('error'):
        print_error("App data linking: FAILED")
    else:
        print_success("App data linking: PASSED")
        print(f"  PortfolioAccount: {'✓' if linking_results.get('portfolio_accounts') else '✗'}")
        print(f"  RiskProfile: {'✓' if linking_results.get('risk_profile') else '⚠ (optional)'}")
        print(f"  Signal: {'✓' if linking_results.get('signals') else '⚠ (none found)'}")
        print(f"  APIKey: {'✓' if linking_results.get('api_keys') else '⚠ (none found)'}")
    
    print()
    print_success("Authentication flow test completed!")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
