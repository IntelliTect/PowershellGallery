﻿using Dropbox.Api;
using IntelliTect.Security;
using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Threading.Tasks;

namespace IntelliTect.PSDropbin
{
    public class PKCEHelper
    {
        // This loopback host is for demo purpose. If this port is not
        // available on your machine you need to update this URL with an unused port.
        private const string LoopbackHost = "http://127.0.0.1:52475/";

        // URL to receive OAuth 2 redirect from Dropbox server.
        // You also need to register this redirect URL on https://www.dropbox.com/developers/apps.
        private readonly Uri RedirectUri = new Uri(LoopbackHost + "authorize");

        // URL to receive access token from JS.
        private readonly Uri JSRedirectUri = new Uri(LoopbackHost + "token");

        /// <summary>
        /// Handles the redirect from Dropbox server. Because we are using token flow, the local
        /// http server cannot directly receive the URL fragment. We need to return a HTML page with
        /// inline JS which can send URL fragment to local server as URL parameter.
        /// </summary>
        /// <param name="http">The http listener.</param>
        /// <returns>The <see cref="Task"/></returns>
        private async Task HandleOAuth2Redirect(HttpListener http)
        {
            var context = await http.GetContextAsync();

            // We only care about request to RedirectUri endpoint.
            while (context.Request.Url.AbsolutePath != RedirectUri.AbsolutePath)
            {
                context = await http.GetContextAsync();
            }

            context.Response.ContentType = "text/html";

            string directoryName = Path.GetDirectoryName(new Uri(System.Reflection.Assembly.GetExecutingAssembly().CodeBase).LocalPath);
            // Respond with a page which runs JS and sends URL fragment as query string
            // to TokenRedirectUri.
            using (var file = File.OpenRead(Path.Combine(directoryName, "index.html")))
            {
                file.CopyTo(context.Response.OutputStream);
            }

            context.Response.OutputStream.Close();
        }

        /// <summary>
        /// Handle the redirect from JS and process raw redirect URI with fragment to
        /// complete the authorization flow.
        /// </summary>
        /// <param name="http">The http listener.</param>
        /// <returns>The <see cref="OAuth2Response"/></returns>
        private async Task<Uri> HandleJSRedirect(HttpListener http)
        {
            var context = await http.GetContextAsync();

            // We only care about request to TokenRedirectUri endpoint.
            while (context.Request.Url.AbsolutePath != JSRedirectUri.AbsolutePath)
            {
                context = await http.GetContextAsync();
            }

            return new Uri(context.Request.QueryString["url_with_fragment"]);
        }

        /// <summary>
        /// Acquires a dropbox OAuth tokens and saves them to the default settings for the app.
        /// <para>
        /// This fetches the OAuth tokens from the applications settings, if it is not found there
        /// (or if the user chooses to reset the settings) then the UI in <see cref="LoginForm"/> is
        /// displayed to authorize the user.
        /// </para>
        /// </summary>
        /// <returns>A valid access token if successful otherwise null.</returns>
        public async Task<string> GetOAuthTokensAsync(string[] scopeList, IncludeGrantedScopes includeGrantedScopes, string driveName)
        {
            Settings.Default.Upgrade();

            string accessTokencredentialName = DropboxDriveInfo.GetDropboxAccessTokenName(driveName);

            if (string.IsNullOrEmpty(CredentialManager.ReadCredential(accessTokencredentialName)))
            {
                string apiKey = GetApiKey();

                using (HttpListener http = new HttpListener())
                {
                    try
                    {
                        string state = Guid.NewGuid().ToString("N");
                        var OAuthFlow = new PKCEOAuthFlow();
                        var authorizeUri = OAuthFlow.GetAuthorizeUri(
                            OAuthResponseType.Code, apiKey, RedirectUri.ToString(),
                            state: state, tokenAccessType: TokenAccessType.Offline,
                            scopeList: scopeList, includeGrantedScopes: includeGrantedScopes);

                        http.Prefixes.Add(LoopbackHost);

                        http.Start();

                        // Use StartInfo to ensure default browser launches.
                        ProcessStartInfo startInfo = new ProcessStartInfo(
                            authorizeUri.ToString())
                        { UseShellExecute = true };

                        try
                        {
                            // open browser for authentication
                            Console.WriteLine("Waiting for credentials and authorization.");
                            Process.Start(startInfo);
                        }
                        catch (Exception)
                        {
                            Console.WriteLine("An unexpected error occured while opening the browser.");
                        }

                        // Handle OAuth redirect and send URL fragment to local server using JS.
                        await HandleOAuth2Redirect(http);

                        // Handle redirect from JS and process OAuth response.
                        Uri redirectUri = await HandleJSRedirect(http);

                        http.Stop();

                        // Exchanging code for token
                        var result = await OAuthFlow.ProcessCodeFlowAsync(
                            redirectUri, apiKey, RedirectUri.ToString(), state);
                        if (result.State != state)
                        {
                            // NOTE: Rightly or wrongly?, state is not returned or else
                            // we would return null here.  
                            // See issue https://github.com/dropbox/dropbox-sdk-dotnet/issues/248
                            Console.WriteLine("The state in the response doesn't match the state in the request.");
                        }
                        Console.WriteLine("OAuth token acquire complete");

                        CredentialManager.WriteCredential(
                            DropboxDriveInfo.GetDropboxAccessTokenName(driveName),
                            result.AccessToken
                            );
                        CredentialManager.WriteCredential(
                            DropboxDriveInfo.GetDropboxRefreshTokenName(driveName),
                            result.RefreshToken
                            );
                        UpdateSettings(result);
                    }
                    catch (Exception e)
                    {
                        Console.WriteLine("Error: {0}", e.Message);
                        return null;
                    }
                }
            }

            return CredentialManager.ReadCredential(accessTokencredentialName);
        }

        private static void UpdateSettings(OAuth2Response result)
        {
            // Foreach Settting, save off the value retrieved from the result.
            foreach (System.Configuration.SettingsProperty item in Settings.Default.Properties)
            {
                if (typeof(OAuth2Response).GetProperty(item.Name) is System.Reflection.PropertyInfo property)
                {
                    Settings.Default[item.Name] = property.GetValue(result);
                }
            }

            Settings.Default.AccessTokenExpiration = result.ExpiresAt != null ? (DateTime)result.ExpiresAt : DateTime.Now;

            Settings.Default.Save();
            Settings.Default.Reload();
        }

        /// <summary>
        /// Retrieve the ApiKey from the user
        /// </summary>
        /// <returns>Return the ApiKey specified by the user</returns>
        private static string GetApiKey()
        {
            string apiKey = Settings.Default.ApiKey;

            while (string.IsNullOrWhiteSpace(apiKey))
            {
                Console.WriteLine("Create a Dropbox App at https://www.dropbox.com/developers/apps.");
                Console.Write("Enter the API Key (or 'Quit' to exit): ");
                apiKey = Console.ReadLine();
                if (apiKey.ToLower() == "quit")
                {
                    Console.WriteLine("The API Key is required to connect to Dropbox.");
                    apiKey = null;
                    break;
                }
                else
                {
                    Settings.Default.ApiKey = apiKey;
                }
            }

            return string.IsNullOrWhiteSpace(apiKey) ? null : apiKey;
        }
    }
}
