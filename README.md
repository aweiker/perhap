# perhap
Perhap is an purely functional event store and service framework inspired by domain driven design and reactive architectures.

## Project status

**Perhap is not currently ready for *your* production use.** It is being used in production, but we don't recommend you do that yet unless you're willing to dig deep into source code when something doesn't work the way you expect.

Before we comfortably call this production ready, we'll have tens or hundreds of millions of events behind us, and be maintaining models for tens or hundreds of thousands of entities, all in production.

Ultimately, Perhap base will be in this repository, and you'll have your choice of database backends and message busses to pull in from other repositories.

## Perhap

Perhap is an event store and service framework. That means you can send it events, and it will share those events with services that have registered an interest in them so that the services can use those events to update their projections (or reductions).

Perhap is "purely functional" in that events are immutable and services are implemented as pure functions.

Perhap is inspired by domain driven design in that it implements a bounded context containing domain services that manage entity models that are created and updated based on domain events.

A *bounded context* provides the logical and semantic context for entities, models, and events. It's also a security realm for accessing models and events. Bounded contexts own their own entities, domain services, models, and events.

A *domain* is an area of activity within a bounded context.

An *entity* is anything with identity that may be modeled within a bounded context.

An *event* is something that happens, typically in the real world, and affects how a domain might model an entity.

A *model* is a representation of an entity within a domain.

As an event store, Perhap can receive events, persist them, and deliver them. In its current form, it receives events by HTTP, persists them to Riak or Cassandra, and delivers them either by HTTP or to a registered domain service.

As a DDD framework, Perhap can deliver events along with a persisted model to a domain service, which is expected to transform that model with those events, and return the transformed model along with any new events the service wants published. Perhap also allows clients to access those models by HTTP and subscribe to changes to a model over a web socket.

### Perhap event store

Events are POSTed to Perhap over HTTP this format, `perhap_server/:bounded_context/:domain/:entity/:event_type/:event_id`, with arbitrary data.

`:bounded_context` represents the name of a context. This context must be configured within Perhap and attached to an authentication source.

`:domain` and `:event_type` work together to define the type of event. `:domain` is the primary domain service that will receive the event, though any domain within a bounded context can register to receive events of a given type from other domains. `:event_type` represents what kind of event occurred. Both `:domain` and `:event_type` are declared by the Perhap client, and are not configured within Perhap; any client authenticated within a bounded context may create events for arbitrary domains and of arbitrary types.

`:entity` is the UUIDv4 ID of an entity within the bounded context. This ID is originally created by a client, not by Perhap. Perhap does not expect to know about (or create) an entity before receiving events related to an entity.

`:event_id` is the UUIDv1 (timeuuid) ID of an event. This is always generated by the client, and should be created when the event happens, not when it is sent to Perhap. This ID will be used to order events.

Events are retrieved from Perhap by GETting them over HTTP by either `:event_id` or `:entity_id` in these formats:

`perhap_server/event/:bounded_context/:event_id`

`perhap_server/events/:bounded_context/:entity_id`

### Perhap framework

As a framework, Perhap allows you to consume incoming events in order to maintain domain models of your entities within a bounded context. Common tasks required within such a pattern are done by Perhap, so that the domain service is strictly responsible for strictly responsible for maintaining the integrity of the model by applying business logic as reducers within a pure function (or composition of functions).

Perhap is responsible for:

* Receiving and persisting events
* Persisting domain models
* Delivering domain models and incoming events to domain services
* Allowing consumers to query the state of a domain model, given an entity ID
* Allowing consumers to subscribe to updates to those domain models when they change

## Example application: e-commerce shopping cart with analytics

Shopping carts are a typical example for choosing an immutable event store over a mutable database, because recording the actions a user takes regarding a shopping cart provides rich information into shopping behaviors, rather than merely the current contents of a shopping cart.

Consider these actions:

0. A visitor to an e-commerce site adds an item to their cart.
0. The shopper adds more items to their cart.
0. Then, they remove an item.
0. The shopper adds a discount code.
0. The shopper proceeds to checkout.

In this scenario, a typical mutable database meets the basic requirements of allowing the user to place an order, but it discards information about the visitor's behaviors that will be useful in providing analytics around the shopping experience unless those are collected separately.

For example, beyond the obvious "what's in the cart?", here are some questions we might want to answer:

0. How old is the cart?
0. How much time passes between events around the cart?
0. What items did the shopper put in the cart and then take back out again?
0. How long did those items stay in the cart?
0. What's the relationship between the maximum value of the cart and the value of the cart at checkout?
0. When in their shopping process did the shopper add the discount code?
0. What items are most frequently removed from carts before checkout?
0. What items are most closely correlated to an abandoned cart?

There are many other questions that a shop owner may be interested in, but these are just some examples.

We can use perhap with a handful of domain services to answer all of these questions in real time.

* A cart service can keep track of what's currently in the cart, and allow the shopper and the store to see the current contents.
* A cart analytics service can keep track of what carts are in circulation, along with statistics around those carts.
* A product analytics service can keep track of how shoppers relate to the products they put in their cart.
* Other analytics may pay attention to coupons and discount codes.

All of these services are paying attention to the same events around many of the same entities within the same bounded context, but representing different views (or projections) generated from those events.

### Perhap and Elm or React/Redux

The shopping cart example demonstrates how Perhap can be well matched to an Elm or React plus Redux front end.

The basic Elm pattern uses four main parts: the model, an update function that responds to events, a view function that updates the display, and subscriptions that can receive data and events from an external source.

Perhap maintains models (reductions or projections) representing entities within a domain that can become part of an Elm or Redux model as well. Populating that model can be done by querying Perhap for the current state of an entity within a domain. The front end can subscribe to changes over websockets to keep that model fresh in real time, and keep the visitors view of that model up to date in real time. When the user of a web app interacts with entities in the bounded context, they generate new events that are published to Perhap.

## Using Perhap

In it's current state, Perhap is an umbrella project with domain services implemented as umbrella apps and given domain events and models. This is not its final form.

### Using Perhap as an Elixir library

This use case is coming soon.

As an Elixir library, Perhap can be added to a projects dependencies, configured for the appropriate backend database, and started as an application. The developer then sets up events much like we use routes in a web framework like Phoenix, pattern matching on incoming events and then passing them along with a persisted model to a reducer function. If the reducer relies on more than one model, all of the models can be retrieved and delivered to the reducer. The reducer function returns one transformed model, and zero or more new events for Perhap to distribute.

Perhap maintains routes for receiving new events over HTTP, answering queries for lists of events by event ID or entity ID, delivering models representing entities within a domain, and delivering updates to a model over websockets.

### Using Perhap as a service

This use case is coming later.

As a service, Perhap provides an event store and distribution framework. Incoming events are persisted and then published to a message bus where services can subscribe to the messages they use. Alternatively, services running on the Erlang virtual machine can register a pattern for events of interest along with their PID, and receive messages when matching events are received. Typically such services are expected to maintain their own model persistence, but Perhap will receive models back on request and make them available to its clients within a bounded context.

## Perhap is Reactive

Perhap is a [reactive system](http://www.reactivemanifesto.org/) and is intended to support and fulfill the expected characteristics of a reactive architecture in several ways.

*Responsive*.Perhap is designed to receive and persist events in 10 milliseconds or less, typically 3 or 4 milliseconds. Once an event is received, it will pass it to subscribed services along with their models. As pure functions, those services are typically also able to perform reductions in a responsive, predictable, and consistent manner so that the full loop from receiving an event to delivering an updated model can be considered reactive.

*Resilient* Perhap uses back ends based on the Dynamo Paper for persisting both events and models. So far, versions have been built using Riak, DynamoDB, and Cassandra. The Perhap API and domain services are implemented using a stateless pattern that can be distributed across an arbitrary number of nodes without need for coordination beyond load balancing.

*Elastic* Perhap's API, database back end, and reducers are designed to push any contention points or bottlenecks down to the level of an individual entity within a bounded context, which is then managed as back pressure. As a framework, Perhap runs domain services (reducers) as separate processes only in response to an event, and the process is terminated when the reduction is complete. Perhap is fully event driven, making monitoring easy both on a standard level (analytics around events and models are provided out of the box) and custom level (domain specific modelling of events and services requires only deploying another reducer and subscribing to relevant system or domain events.)

*Event driven* Perhap's core abstraction is the event, both internally and externally. These asynchronous messages support an architecture that is inherently location transparent, loosely coupled, and isolated.