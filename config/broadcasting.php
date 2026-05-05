<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Broadcaster
    |--------------------------------------------------------------------------
    |
    | This option controls the default broadcaster that will be used by the
    | framework when an event needs to be broadcast. You may set this to
    | any of the connections defined in the "connections" array below.
    |
    | Supported: "pusher", "ably", "redis", "log", "null"
    |
    */

    'default' => env('BROADCAST_DRIVER', 'null'),

    /*
    |--------------------------------------------------------------------------
    | Broadcast Connections
    |--------------------------------------------------------------------------
    |
    | Here you may define all of the broadcast connections that will be used
    | to broadcast events to other systems or over websockets. Samples of
    | each available type of connection are provided inside this array.
    |
    */

    'connections' => [
        'pusher' => [
            'driver' => 'pusher',
            'key' => env('PUSHER_APP_KEY'),
            'secret' => env('PUSHER_APP_SECRET'),
            'app_id' => env('PUSHER_APP_ID'),
            'options' => [
                'cluster' => env('PUSHER_APP_CLUSTER', 'mt1'),
                'useTLS'  => env('PUSHER_SERVER_USE_TLS', env('PUSHER_USE_TLS', false)),
                'host'    => env('PUSHER_SERVER_HOST', env('PUSHER_HOST', '127.0.0.1')),
                'port'    => env('PUSHER_SERVER_PORT', env('PUSHER_PORT', 6001)),
                'scheme'  => env('PUSHER_SERVER_SCHEME', env('PUSHER_SCHEME', 'http')),
            ],
        ],
        // 'pusher' => [
        //     'app_id' => env('PUSHER_APP_ID'),
        //     'client_options' => [
        //         // Guzzle client options: https://docs.guzzlephp.org/en/stable/request-options.html
        //     ],
        //     'driver' => 'pusher',
        //     'key' => env('PUSHER_APP_KEY'),
        //     'options' => [
        //         'cluster' => env('PUSHER_APP_CLUSTER'),
        //         'useTLS' => true,
        //     ],
        //     'secret' => env('PUSHER_APP_SECRET'),
        // ],
        'ably' => [
            'driver' => 'ably',
            'key' => env('ABLY_KEY'),
        ],
        'redis' => [
            'connection' => 'default',
            'driver' => 'redis',
        ],
        'log' => [
            'driver' => 'log',
        ],
        'null' => [
            'driver' => 'null',
        ],
    ],
];
