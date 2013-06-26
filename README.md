# Ember Query

A querystring library for Ember.js. Tested with 1.0.0-rc.5

**RC6 is not supported yet. Support will be coming within the next few weeks, perhaps sooner. PRs welcome!**

## What is it?

A library enabling url query parameters to be used in ember applications. This feature is slated to be included in Ember.js 1.1, however I needed it now.

## Status

Experimental, but in use in a number of apps. Currently only supports history location, so if you're using hash location in ember this won't help you at all at the moment. Patches welcome.

## Getting Started

After ember.js in your html, include `ember-query.js` and [jquery-deparam](https://github.com/chrissrogers/jquery-deparam)

Then, change your router to use query location:

```javascript
MyApp.Router.reopen({
  location: 'query'
});
```
**Important** - this will only work if you're currently using `location: 'history'`. If you are not, i.e. you are using the default which is `hash`, this will probably just cause everything to explode.

## Route Callbacks

There are new callbacks on each route, `serializeParams` and `deserializeParams`. The idea for serialize is to take the controller state and generate query params for the controller. Deserialize generates controller state from the query string. This is similar to how the `model` and `serialize` hooks currently work with the main difference being that query params are global rather than scoped to specific routes.

```javascript
MyApp.Router.map(function() {
  this.resource('foo', function() {
    this.route('bar');
  });
});

MyApp.FooRoute = Em.Route.extend({
  serializeParams: function(controller) {
    return {
      foo_type: controller.get('fooType'),
      page: controller.get('page')
    };
  },

  // deserializeParams is called whenever the params cahnge
  deserializeParams: function(params, controller) {
    controller.set('fooType', params.foo_type);
  },

  // setupController is only called when params change and this route
  // is the current child route (not a parent of the current state)
  // Query params are passed as the third argument to this hook now
  setupController: function(controller, context, params) {
    controller.set('page', params.page);
  },
  
  // query params are passed as the second argument to the model hook
  // in case you need to use them to affect the model
  model: function(params, queryParams) {
    page = queryParams.page || 1;
    return MyApp.Things.find({page: page});
  }
});
```

When serializing, the params from all routes are merged, e.g. if you are in state foo.bar.baz, all routes in that tree will have serialize called on them, and the result merged to generate the query string, with params from the child states taking precedence over params from the parent states with the same name.

If you want something like a global filter param that applies across states, then add serializeParams / deserializeParams hooks to the common parant of those states.

## Binding params to controller properties

When defining controllers, you need to provide a list of properties that affect params in some way, e.g:

```javascript
MyApp.FooController = Em.Controller.extend({
  observeParams: ['propertyone', 'myList.@each']
});
```

Note that these properties don't need to actually be the ones that are the params, as changing of these properties just triggers the serialization process.

## Transitioning parameters

In controllers and routes there are some new helpers:

```javascript
MyApp.BarController = Em.Controller.extend({
  // transition param_name to be 'param_value', adding an
  // entry in your history
  buttonClicked: function() {
    return this.transitionParams({
      param_name: 'param_value'
    });
  },

  // as above but replaces all current params instead of merging
  otherButtonClicked: function() {
    return this.transitionAllParams({ foo: 'bar' });
  },

  // Just like normal transitionToRoute but with added query params
  yetAnotherButtonClicked: function() {
    var context;
    context = this.get('someModel');
    return this.transitionToRouteWithParams('foo.bar', model, {
      page: 2
    });
  },

  // replace the current parameters without adding a state to the
  // browser history
  finalButtonClicked: function() {
    this.replaceQueryParams({ foo: 'bar' });
  },

  // currentParams returns the current query params as an object.
  doSomething: function() {
    console.log(this.currentParams());
  }
});

```

These helpers will transition appropriately and run the `deserializeParams` hook in all routes in the current state tree, which should apply the values to controllers appropriately.

## Specifying query params in the {{linkTo}} helper



```handlebars
{{#linkTo new.route query="foo=bar&type[]=1&type[]=2"}}
  Click me
{{/linkTo}}
```

Right now, the implementation is pretty hacky but it seems to work OK and also seems to make sense conceptually. I'd be really interested in any feedback on the general idea of how it works, along with general bug reports and patches.
