Marionette.AppController
========================

A base controller (as in MVC) with before-filters for Marionette apps

### Why?

Marionette establishes all kinds of *great* conventions on top of Backbone, which specifies very few. It does this mostly with a new set of slightly more opinionated base classes such as it's various views and `AppRouter`, but like Backbone, it assumes that your controller will be a dumb JavaScript object.

AppController provides...
- Strong organizational conventions such as the use of `initialize` like *every other class* you're likely to define in a Marionette app
- Use `_method` to denote "private" (non-routable) methods
- Use `beforeFilter` to run some code before any action is invoked
- Use `render ViewName, arg1, arg2` to render a view
- Use `redirect "a/new/path"` to update the URL and trigger routing
- Use `fixupUrl "a/new/path"` to update the URL and *not* trigger routing

```CoffeeScript
App.addRegion(content: '#content')

class UsersController extends Marionette.AppController
  initialize: ->
    beforeFilter @loginPrompt, only: ['edit', 'destroy']

  _loginPrompt: ->
    unless prompt('What is the secret password?') == 'password'
      # Prevents edit/destroy actions from being invoked
      @redirect '/auth_required'
      
  show: (id) ->
    user = new App.Models.User(id: id)
    user.fetch
    # Render the view, with the given arguments, into our 'content' region
    @render App.Views.ShowUserView, model: user
```

Neither Backbone or Marionette give you a base class for your controllers. Marionette.AppController provides this missing class, with a few strong(ish) conventions to make your life easier.

It provides a few Rails-inspired methods for use in your views that should make your life a little easier if conventions are followed.

### Setup

*Note: Marionette defaults to looking for certain properties on a global `App`, such as `App.router` or `App.container`. If you don't have them, you'll have to be more explicit, see below.*

1. AppController assumes you are going to be showing a few different types of top-level views in one "master" region.

 A typical page should contain a single container div...

 ```html
 <div id="content"></div>
 ```

 AppController expects you'll give it a container as a property of your controller called `content:` (otherwise it will try to use `App.content`):

 Either...
 
 ```CoffeeScript
 # Make App.content accessable
 App.addRegion(content: '#content')
 ```
 
 or...
 
 ```CoffeeScript
 # Give your controller a content region
 class UserController extends Marionette.AppController
   content: Marionette.Region.extend(el: '#content')
```

2. AppController assumes you'll have a router, and that it will either be...

  - given to it as a `router:` property of your sub-class
  
   ```CoffeeScript   
   class UsersController extends Marionette.AppController
     router: new RouterClass()
   ```
    
  - *OR* assgined to an instance of your controller after its created
  
   ```CoffeeScript
   controller = new UsersController
   controller.router = new RouterClass
   ```  

  - *OR* available globally as `App.router`.

   ```CoffeeScript
   App.router = new RouterClass
   controller = new UsersController
   ```
  
  In any event, it doesn't *need* your router unless you intend to use the `fixupUrl` or `redirect` methods

3. Name your routable actions normally; name all other methods on your controller with a leading underscore, to denote them as private.


### Usage

AppController provides several useful features

- `beforeFilter`
  In your controllers `initialize` methods, you can define Rails-style before-filters which can halt the actual invocation of the given method by rendering or redirecting. Before-filter methods must have a leading underscore, as should any *non-action* methods on your controller. You can use `only:` or `except:` to list actions that are protected/omitted from the before-filter.

```CoffeeScript
class MyController extends Marionette.AppController
  initialize: ->
    @beforeFilter 'requireUser', except: ['login']
    @beforeFilter 'showOnboardingDialog', only: ['index']
    
  _requireUser: ->
    @redirect '/login' unless App.currentUser
  
  _showOnboardingDialog: ->
    new App.Views.OnboardingPopup.show()
    
  index: ->
    # requireUser has run
    # showOnboarding has run
    
  show: ->
    # requireUser has run
    # showOnboarding has not run

  login: ->
    # Neither before-filter has run
```

- `render` - Render a view, and halt before-filters

 Use `@render ViewClass [, arg1 [, arg2] ]` to render a view. If called from a before filter, any subsequent before filters are skipped and the originally invoked action isn't invoked.

- `redirect` - Redirect to a new URL, and half before-filters

 Use `@redirect 'path' [,options = {}]` to redirect to a new URL,  triggering routing by default. Arguments are passed through to `@router.navigate path, options`, with the caveat that `options.trigger` defaults to `true`.
 
 Use `@redirect 'path', notice: 'a message'` or `error: 'a message'` to trigger "flash" messages upon redirect. AppController will simply invoke `@flash` if it exists, passing in `notice: '...'` or `error: '...'`, it's up to you to handle this.
 
- `fixupUrl` - Replace the URL with a different URL

 Use `@fixupUrl 'path' [, options = {}]` to replace the URL without routing. Arguments are passed through to `@router.navigate path, options` with the caveat that `options.replace` defaults to `true`.

