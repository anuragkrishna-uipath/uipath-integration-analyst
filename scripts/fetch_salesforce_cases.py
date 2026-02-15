#!/usr/bin/env python3
"""
Fetch Salesforce Integration Service Cases with SSO Support
"""
import os
import sys
import json
from datetime import datetime
from simple_salesforce import Salesforce, SalesforceLogin
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading

# Load environment variables from .env file
try:
    with open('.env', 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                os.environ[key.strip()] = value.strip()
except FileNotFoundError:
    pass

class OAuthCallbackHandler(BaseHTTPRequestHandler):
    """Handle OAuth callback"""
    authorization_code = None

    def do_GET(self):
        query_components = parse_qs(urlparse(self.path).query)

        if 'code' in query_components:
            OAuthCallbackHandler.authorization_code = query_components['code'][0]
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"""
                <html>
                <body>
                    <h1>Authentication Successful!</h1>
                    <p>You can close this window and return to the terminal.</p>
                    <script>window.close();</script>
                </body>
                </html>
            """)
        else:
            self.send_response(400)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress log messages


def authenticate_with_username_password():
    """Authenticate using username, password, and security token"""
    username = os.getenv('SALESFORCE_USERNAME')
    password = os.getenv('SALESFORCE_PASSWORD')
    security_token = os.getenv('SALESFORCE_SECURITY_TOKEN')
    domain = os.getenv('SALESFORCE_DOMAIN', 'login')  # 'login' or 'test'

    if not all([username, password, security_token]):
        print("\n" + "="*80)
        print("USERNAME/PASSWORD AUTHENTICATION")
        print("="*80)
        print("\nFor SSO with security token, you need:")
        print("1. Your Salesforce username (email)")
        print("2. Your Salesforce password")
        print("3. Your security token (reset in Salesforce: My Settings > Reset Security Token)")
        print("4. Add to .env file:")
        print("   SALESFORCE_USERNAME=your-email@company.com")
        print("   SALESFORCE_PASSWORD=your-password")
        print("   SALESFORCE_SECURITY_TOKEN=your-security-token")
        print("="*80 + "\n")
        return None

    try:
        sf = Salesforce(
            username=username,
            password=password,
            security_token=security_token,
            domain=domain
        )
        print(f"✓ Authenticated successfully using username/password")
        return sf
    except Exception as e:
        print(f"✗ Authentication failed: {str(e)}")
        return None


def authenticate_with_session_id():
    """Authenticate using session ID from browser"""
    instance_url = os.getenv('SALESFORCE_INSTANCE_URL', 'https://uipath.my.salesforce.com')
    session_id = os.getenv('SALESFORCE_SESSION_ID')

    if not session_id:
        print("\n" + "="*80)
        print("SESSION ID AUTHENTICATION")
        print("="*80)
        print("\nTo get your Session ID:")
        print(f"1. Open your browser and go to: {instance_url}")
        print("2. Log in via SSO")
        print("3. Open Developer Tools (F12)")
        print("4. Go to Console tab and run:")
        print("   document.cookie.split(';').find(c => c.includes('sid')).split('=')[1]")
        print("5. Copy the session ID and set it in .env file:")
        print("   SALESFORCE_SESSION_ID=your-session-id")
        print("="*80 + "\n")
        return None

    try:
        sf = Salesforce(instance_url=instance_url, session_id=session_id)
        print(f"✓ Authenticated successfully using Session ID")
        return sf
    except Exception as e:
        print(f"✗ Authentication failed: {str(e)}")
        return None


def authenticate_with_oauth():
    """Authenticate using OAuth 2.0 (requires Connected App)"""
    instance_url = os.getenv('SALESFORCE_INSTANCE_URL', 'https://uipath.my.salesforce.com')
    client_id = os.getenv('SALESFORCE_CLIENT_ID')
    client_secret = os.getenv('SALESFORCE_CLIENT_SECRET')
    redirect_uri = os.getenv('SALESFORCE_REDIRECT_URI', 'http://localhost:8080/callback')

    if not client_id or not client_secret:
        print("\n" + "="*80)
        print("OAUTH AUTHENTICATION")
        print("="*80)
        print("\nOAuth requires a Connected App in Salesforce:")
        print("1. In Salesforce Setup, search for 'App Manager'")
        print("2. Create a New Connected App")
        print("3. Enable OAuth Settings")
        print("4. Set Callback URL to: http://localhost:8080/callback")
        print("5. Add OAuth Scopes: api, refresh_token")
        print("6. Copy Consumer Key and Consumer Secret to .env:")
        print("   SALESFORCE_CLIENT_ID=your-consumer-key")
        print("   SALESFORCE_CLIENT_SECRET=your-consumer-secret")
        print("="*80 + "\n")
        return None

    # OAuth flow
    auth_url = (
        f"{instance_url}/services/oauth2/authorize?"
        f"response_type=code&client_id={client_id}&redirect_uri={redirect_uri}"
    )

    print(f"\nOpening browser for authentication...")
    print(f"If browser doesn't open, go to: {auth_url}\n")
    webbrowser.open(auth_url)

    # Start local server to receive callback
    server = HTTPServer(('localhost', 8080), OAuthCallbackHandler)
    print("Waiting for authentication callback...")
    server.handle_request()

    if not OAuthCallbackHandler.authorization_code:
        print("✗ Authentication failed: No authorization code received")
        return None

    # Exchange code for access token
    import requests
    token_url = f"{instance_url}/services/oauth2/token"
    token_data = {
        'grant_type': 'authorization_code',
        'code': OAuthCallbackHandler.authorization_code,
        'client_id': client_id,
        'client_secret': client_secret,
        'redirect_uri': redirect_uri
    }

    response = requests.post(token_url, data=token_data)
    if response.status_code != 200:
        print(f"✗ Token exchange failed: {response.text}")
        return None

    token_info = response.json()

    try:
        sf = Salesforce(
            instance_url=token_info['instance_url'],
            session_id=token_info['access_token']
        )
        print(f"✓ Authenticated successfully using OAuth")
        return sf
    except Exception as e:
        print(f"✗ Authentication failed: {str(e)}")
        return None


def fetch_cases(sf, days=7):
    """Fetch integration service cases"""
    try:
        query = f"""
            SELECT Id, CaseNumber, Subject, Status, Priority,
                   CreatedDate, LastModifiedDate, Description,
                   Type, Account.Name, Owner.Name
            FROM Case
            WHERE Type = 'Integration Service'
            AND CreatedDate = LAST_N_DAYS:{days}
            ORDER BY CreatedDate DESC
        """

        print(f"\nQuerying cases from last {days} day(s)...")
        results = sf.query(query)

        print(f"\n{'='*80}")
        print(f"Integration Service Cases - Last {days} Day(s)")
        print(f"Total Cases Found: {results['totalSize']}")
        print(f"{'='*80}\n")

        if results['totalSize'] == 0:
            print("No cases found.")
            return results

        # Group by status
        by_status = {}
        for record in results['records']:
            status = record.get('Status', 'Unknown')
            if status not in by_status:
                by_status[status] = []
            by_status[status].append(record)

        # Print by status
        for status, cases in sorted(by_status.items()):
            print(f"\n## {status} ({len(cases)} case(s))")
            print("-" * 80)
            for case in cases:
                print(f"  Case: {case['CaseNumber']}")
                print(f"  Subject: {case['Subject']}")
                print(f"  Priority: {case.get('Priority', 'N/A')}")
                print(f"  Created: {case['CreatedDate']}")
                print(f"  Owner: {case.get('Owner', {}).get('Name', 'N/A')}")
                if case.get('Account'):
                    print(f"  Account: {case['Account'].get('Name', 'N/A')}")
                if case.get('Description'):
                    desc = case['Description'][:100] + '...' if len(case.get('Description', '')) > 100 else case.get('Description', '')
                    print(f"  Description: {desc}")
                print()

        # Save to JSON
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"salesforce_cases_{timestamp}.json"

        with open(filename, 'w') as f:
            json.dump(results['records'], f, indent=2, default=str)

        print(f"\n{'='*80}")
        print(f"Results saved to: {filename}")
        print(f"{'='*80}\n")

        return results

    except Exception as e:
        print(f"✗ Error fetching cases: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


def main():
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 7

    print("\n" + "="*80)
    print("SALESFORCE SSO INTEGRATION SERVICE CASES")
    print("="*80)
    print(f"Instance: {os.getenv('SALESFORCE_INSTANCE_URL', 'https://uipath.my.salesforce.com')}")
    print(f"Days: {days}")
    print("="*80 + "\n")

    # Try authentication methods in order
    sf = None

    # Method 1: Username/Password (works with SSO if you have security token)
    print("Attempting Username/Password authentication...")
    sf = authenticate_with_username_password()

    # Method 2: Session ID (easiest for SSO)
    if not sf:
        print("\nAttempting Session ID authentication...")
        sf = authenticate_with_session_id()

    # Method 3: OAuth (if other methods fail)
    if not sf:
        print("\nAttempting OAuth authentication...")
        sf = authenticate_with_oauth()

    if not sf:
        print("\n✗ All authentication methods failed.")
        print("\nFor SSO, try one of these methods:")
        print("1. Username/Password + Security Token (recommended for automation)")
        print("2. Session ID (extract from browser after SSO login)")
        print("3. OAuth (requires Connected App setup by IT)")
        sys.exit(1)

    # Fetch cases
    fetch_cases(sf, days)


if __name__ == "__main__":
    main()
