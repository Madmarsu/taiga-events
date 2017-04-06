uuid = require('node-uuid')
signing = require('./signing')
SubscriptionManager = require('./subscription').SubscriptionManager

clients = {}


class Client
    constructor: (@ws) ->
        @.id = uuid.v4()

        @.handleEvents()

    handleEvents: () ->
        @ws.on 'message', @.handleMessage.bind(@)

    handleMessage: (message) ->
        msg = JSON.parse(message)

        if msg.cmd == 'ping'
            @.sendPong()
        else if msg.cmd == 'auth'
            @.authUser(msg.data)
        else if msg.cmd == 'subscribe'
            if msg.routing_key and msg.routing_key.indexOf("live_notifications") == 0
                userId = signing.getUserId(@.auth.token)
                @.addSubscription("live_notifications.#{userId}")
            else
                @.addSubscription(msg.routing_key)
        else if msg.cmd == 'unsubscribe'
            @.removeSubscription(msg.routing_key)

    authUser: (auth) ->
        if auth.token and auth.sessionId and signing.verify(auth.token)
            @.auth = auth

    addSubscription: (routing_key) ->
        if @.auth
            if !@.subscriptionManager
                @.subscriptionManager = new SubscriptionManager(@.id, @.auth, @ws)
            @.subscriptionManager.add(routing_key)

    removeSubscription: (routing_key) ->
        if @.subscriptionManager
            @.subscriptionManager.remove(routing_key)

    sendPong: ->
        @ws.send(JSON.stringify({cmd: "pong"}))

    close: () ->
        if @.subscriptionManager
            @.subscriptionManager.destroy()


exports.createClient = (ws) ->
    client = new Client(ws)
    clients[client.id] = client
    client.ws.on 'close', (() ->
        @.close()
        delete clients[@.id]
    ).bind(client)
