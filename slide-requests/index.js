'use strict';
const simpleParser = require('mailparser').simpleParser;
const aws = require('aws-sdk');
const s3 = new aws.S3();
const ses = new aws.SES({region: process.env.SES_REGION});
const fs = require('fs');


console.log('Loading function');

function sendMail(recipient, url) {
    var mailText = fs.readFileSync('./slide-requests/mail-template.html').toString('UTF-8');
    mailText = mailText.replace(/URL/i, url);
    const params = {
        Destination: { ToAddresses: [recipient] },
        Source: 'talks@marcobuss.de',
        Message: {
            Subject: { Charset: 'UTF-8', Data: 'Slide Request' },
            Body: {
                Html: {
                    Data: mailText
                }
            }
        }
    };

    ses.sendEmail(params, function(err, data) {
        if (err) console.log(err, err.stack); // an error occurred
        else     console.log(data);           // successful response
    });
}

exports.handler = (event, context, callback) => {
    console.log('Received event:', JSON.stringify(event, null, 2));

    const s3Event = event.Records[0].s3;

    s3.getObject({Bucket: s3Event.bucket.name, Key: s3Event.object.key}, function(err, data) {
        if (err) console.log(err, err.stack); // an error occurred
        else {
            simpleParser(data.Body).then(
                mail => {
                    console.log(mail.subject);
                    console.log(mail.from.value[0].address);
                    var params = {
                        Bucket: 'marco.159501877559.slides.oc-papersubmission',
                        Key: 'Der_sprechende_Kickertisch.pdf',
                        Expires: 3600
                    };
                    s3.getSignedUrl('getObject', params, function(err, url) {
                        console.log('The URL is', url);
                        sendMail(mail.from.value[0].address, url);
                    });

                }).catch(err=>{
                console.log(err);
            })
        }
    });
};