// Kubernetes Dashboard Auto-Login Bookmarklet
// 
// To use:
// 1. Copy the token from repo/main/k8s/dashboard-token.txt
// 2. Replace YOUR_TOKEN_HERE with your actual token
// 3. Create a bookmark with this code as the URL (prefixed with javascript:)
// 4. When on the dashboard login page, click the bookmark

(function() {
    // Replace this with your actual token from dashboard-token.txt
    const TOKEN = 'YOUR_TOKEN_HERE';
    
    // Find token input field
    const tokenInput = document.querySelector('input[type="text"][placeholder*="token" i], input[type="text"][name*="token" i], input[type="password"]');
    
    if (tokenInput) {
        // Set token value
        tokenInput.value = TOKEN;
        tokenInput.type = 'text'; // Make it visible if it's password type
        
        // Trigger input event
        const inputEvent = new Event('input', { bubbles: true });
        tokenInput.dispatchEvent(inputEvent);
        
        // Trigger change event
        const changeEvent = new Event('change', { bubbles: true });
        tokenInput.dispatchEvent(changeEvent);
        
        // Try to find and click the login button
        setTimeout(() => {
            const loginButton = document.querySelector('button[type="submit"], button:contains("Sign"), button:contains("Login"), md-button:contains("Sign")');
            if (loginButton) {
                loginButton.click();
            } else {
                // Try Angular Material button
                const mdButton = document.querySelector('md-button[type="submit"]');
                if (mdButton) {
                    mdButton.click();
                } else {
                    alert('Token filled! Please click the Sign In button manually.');
                }
            }
        }, 500);
        
        console.log('Token auto-filled successfully!');
    } else {
        alert('Token input field not found. Please paste the token manually.\n\nToken: ' + TOKEN);
        // Copy token to clipboard
        if (navigator.clipboard) {
            navigator.clipboard.writeText(TOKEN).then(() => {
                console.log('Token copied to clipboard');
            });
        }
    }
})();

