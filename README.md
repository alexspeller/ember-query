# Ember Query

A querystring library for Ember.js. Tested with 1.0.0-RC.1

## What is it?

A library enabling url query parameters to be used in ember applications. This features is slated to be included in Ember.js 1.1, however I needed it now.

## Status

Highly experimental. Currently only supports history location, so if you're using hash location in ember this won't help you at all at the moment. Patches welcome.

## Getting Started

After ember.js in your html, include `ember-query.js` and [jquery-deparam](https://github.com/chrissrogers/jquery-deparam)

Then, change your router to use query location

```coffeescript
App.Router.reopen
  location: 'query'
```

There are new callbacks on each route, `serializeParams` and `deserializeParams`. The idea for serialize is to take the controller state and generate query params for the controller. Deserialize generates controller state from the query string. This is similar to how the `model` and `serialize` hooks currently work with the main difference being that query params are global rather than scoped to specific routes.

```coffeescript

App.Router.map ->
  @resource 'foo', ->
    @route 'bar'

App.FooRoute = Em.Route.extend
  serializeParams: (controller) ->
    foo_type: controller.get('fooType')
    page: controller.get('page')

  # deserializeParams is called whenever params change
  deserializeParams: (params) ->
    @controllerFor('foo').set('fooType', params.foo_type)

  #setupController is only called when params change and this route is
  # the current child route (not a parent of the current state)
  setupController: (controller, context, params) ->
    controller.set('page', params.page)

App.BarRoute = Em.Route.extend
  events:
    buttonClicked: ->
      @transitionParams fooType: 'bar'

App.FooController = Em.Controller.extend
  # When these properties change, all serializeParams hooks in current
  # active state tree will be called to generate the new params for the querystring.
  observeParams: ['fooType', 'page']
```

When serializing, the params from all routes are merged, e.g. if you are in state foo.bar.baz, all routes in that tree will have serialize called on them, and the result merged to generate the query string, with params from the child states taking precedence over params from the parent states with the same name.

If you want something like a global filter param that applies across states, then add serializeParams / deserializeParams hooks to the common parant of those states.

When defining controllers, you need to provide a list of properties that affect params in some way, e.g:

```coffeescript
App.FooController = Em.Controller.extend
  observeParams: ['propertyone', 'myList.@each']
```

Note that these properties don't need to actually be the ones that are the params, as changing of these properties just triggers the serialization process.

Finally, in controllers and routes there are some new helpers:

```coffeescript
App.BarController = Em.Controller.extend
  buttonClicked: ->
    # transition param_name to be 'param_value', adding an
    # entry in your history
    @transitionParams param_name: 'param_value'

  otherButtonClicked: ->
    # as above but replaces all current params instead of merging
    @transitionAllParams foo: 'bar'

  yetAnotherButtonClicked: ->
    # Just like normal transitionToRoute but with added query params
    context = @get('someModel')
    @transitionToRouteWithParams 'foo.bar', model, page: 2

  finalButtonClicked: ->
    # replace the current parameters without adding a state to the
    # browser history
    @replaceQueryParams foo: 'bar'

  doSomething: ->
    # currentParams returns the current query params as an object.
    console.log @currentParams()

```

These helpers will transition appropirately and run the `deserializeParams` hook in all routes in the current state tree, which should apply the values to controllers appropriately.

Right now, the implementation is pretty hacky but it seems to work OK and also seems to make sense conceptually. I'd be really interested in any feedback on the general idea of how it works, along with general bug reports and patches.