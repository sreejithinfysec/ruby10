## Security is Broken: Understanding Common Vulnerabilities

This is an application to accompany my "Security is Broken: Understanding Common
Vulnerabilties" talk. To learn more about where I'm giving this talk visit my
[website](http://eileencodes.com/speaking/).

In the master branch it demonstrates three common, well-known vulnerabilities; CSRF,
XSS, and XXE. Then in each "patched" branch I explain ways to fix and avoid the
vulnerabilities.

These examples are relatively basic and are intended to be usable for those who don't
necessarily use Rails often.

### Setting Up the Application

You will need to have Ruby 2.2.2 installed because it's required by Rails 5. I used
the most recent version of Rails to demonstrate these vulnerabilities because they
are ones that have existed for a long time, but it is still relatively easy to
accidently expose CSRF, XSS, and XXE attacks if you don't know about them.

You don't need any special databases because this application uses the default; SQLite3.

After you have forked and cloned the application to your environment run the following:

```
bundle install
rails db:setup
```

Start the server

```
rails s
```

## CSRF: Cross-Site Request Forgery Attack

### Exploiting

A CSRF attack uses a malicious site to trick a browser with an active session on another
site into performing an unwanted action.

For example, you have a profile on a website that requires authentication to edit; for
example Facebook or Twitter. If that website isn't checking the authenticity of requests
made to sensitive endpoints, it's possible for an attacker to hijack a request and make
changes to the victim's profile.

To exploit this with the provides application start the server with `rails s`.

Then open the file in `public/csrf_attack.html` in the browser.

Because the file is setup to automatically submit you should see a redirect to the
`localhost:3000` domain notifying you the email address was updated. The email address
of the victim user, user with ID 2, will be changed from "victim@example.com" to
"changed@example.com".

This is just a demonstration of how this could work. Because of browser security
protocols and application defaults in other apps this may be difficult to reproduce
on a real production application.

### Mitigating

Mitigation is relatively easy if you're using an application like Rails. Many modern
frameworks including Django, Java's Spring, Rails, and .net all have built in CSRF
protection.

To enable CSRF protection in Rails add forgery protection to your ApplicationController
to protect sensitive requests. Rails does not protect GET requests because sensitive
requests should never be sent as GET requests.

Add the following to your `ApplicationController`

```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery
end
```

And add the meta tag to your HTML head

```erb
<%= csrf_meta_tags %>
```

### Resources

[OWASP](https://www.owasp.org/index.php/Cross-Site_Request_Forgery_(CSRF))
[Neal Poole's Blob](https://nealpoole.com/blog/2012/03/csrf-clickjacking-and-the-role-of-x-frame-options/)
[pentestmonkey.net](http://pentestmonkey.net/blog/csrf-xml-post-request)
[Per-form CSRF token PR for Rails](https://github.com/rails/rails/pull/22275)

## XSS: Cross-Site Scripting Attack

### Exploiting

XSS attacks inject malicious JavaScript into trusted websites. XSS is easily exploitable
if your application is displaying or evaluating user input that is not sanitized by the
application.

For purposes of this demonstration we're going to focus on stored XSS. Stores XSS
means the attacker inserts a malicious script into your database or filesystem
that will be executed when the victim visits the page containing that script.

To exploit XSS with this demo application start the Rails server with `rails s`.

Visit to "hacker"'s profile page at [http://localhost:3000/users/1](http://localhost:3000/users/1)
and you will see an `alert` on visit that comes from the users name. The reason
this is exploitable is becasue we are running `html_safe` on the user inputted string.

There is a second XSS example on the page in the user's webiste. Using the `javascript://`
scheme the attacker can execute JavaScript when the victim clicks the website in the
profile URL. Because we are using a `link_to` to obscure the real url the victim may
not realize that this specially encoded URL is harmful. Clicking "website" will
execute the javascript after the `%0A` encoding which signals a line feed, aka
move to the next line.

```
javascript://example.com/%0A/alert("1")
```

### Mitigating

By default Rails tries to protect programmers from allowing XSS injection, but if
you purposely enable it, Rails can't protect you.

Never run `html_safe` on user inputted strings without some kind of santizing first.

If you must allow HTML in use input, utilize a sanitizing library like the one that
comes default with ActiveSupport.

```erb
<%= sanitize(user.name) %>
```

This will allow a customizable whitelist of tags but also continue to protect you
from XSS by ensuring that the `img` tag does not allow the `onerror` attribute.

You can also validate user supplied data before inserting it into the database.

The following validator for the user website checks that the only schemes that
our application allows are `http` and `https`. Any websites with another scheme
will be rejected with an error. You should always use a URI parsing library
over a regex for this because it's easy to get regex wrong, but a parsing library
is widely used and tested.

```ruby
class User < ActiveRecord::Base
  WHITELISTED_URI_SCHEMES = %w( http https )

  validate :check_uri_scheme

  private
    def check_uri_scheme
      begin
        uri = URI.parse(website)
        unless WHITELISTED_URI_SCHEMES.include?(uri.scheme.downcase)
          errors.add :website, 'is not an allowed URI scheme'
        end
      rescue URI::InvalidURIError
        errors .add :website, 'is not a valid URI'
      end
    end
end
```

### Resources

[OWASP](https://www.owasp.org/index.php/Cross-site_Scripting_(XSS))
[OWASP Cheat Sheet](https://www.owasp.org/index.php/XSS_(Cross_Site_Scripting)_Prevention_Cheat_Sheet)
[Blackhat Presentation by Eduardo Vela and David Lindsay](https://www.blackhat.com/presentations/bh-usa-09/VELANAVA/BHUSA09-VelaNava-FavoriteXSS-SLIDES.pdf)

## XXE: XML eXternal Entity Attack

### Exploiting

If an application has an endpoint that parses XML an attacker could send a specially
crafted payload to the server and obtain sensitive files. The files the attacker is
able to obtain depend heavily on how your system is setup and user permissions are
implemented.

Using the `xxe.xml` payload file in this repository we can send a cURL request to the
create users endpoint which accepts XML.

```
curl -X 'POST' \
     -H 'Content-Type: application/xml' \
     -d @xxe.xml \
     http://localhost:3000/users.xml
```

The payload will collect the `secrets.yml` file and set it as the user's name when the
request is sent. The `secrets.yml` file will be inserted into the database as the users
name and returned to the attacker.

### Mitigating

* Don't parse XML if it's not an application requirement
* Don't use a library that has supports entity replacement (LibXML). Use the built in
default instead; REXML
* Ensure entity replacement is disabled. New versions of LibXML make it hard to enable
entity replacement. You may still be vulnerable to a DoS attack when using LibXML.

```ruby
>> LibXML::XML.default_substitute_entities
>> false
```

* Whitelist known external entities

### Resources

[OWASP](https://www.owasp.org/index.php/XML_External_Entity_(XXE)_Processing)
[Software Engineering Institute, Carnegie Mellon](https://www.securecoding.cert.org/confluence/display/java/IDS17-J.+Prevent+XML+External+Entity+Attacks)
[LibXML Example](https://github.com/xml4r/libxml-ruby/blob/c46ec53c68e4552c4e6547b52e3f365c3d4d9dd0/test/c14n/given/example-5.xml)
[SANS Hands-On XML External Entity Vulnerability Training](http://www.sans.org/reading-room/whitepapers/application/hands-on-xml-external-entity-vulnerability-training-module-34397)
[ColeSec Security](http://colesec.inventedtheinternet.com/attacking-xml-with-xml-external-entity-injection-xxe/)
