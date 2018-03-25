'use strict';

exports.handler = (event, context, callback) => {
    console.log('Received event:', JSON.stringify(event, null, 2));

    const response = {
        'statusCode': 200,
        'headers': {
            "Access-Control-Allow-Origin": "*"   //Required for CORS support to work
        },
        'body': ''
    };

    callback(null, response);
};