//======================= API Gateway Request Authorizer for BitBucket & GitHub Webhooks =======================
// A REQUEST authorizer that validate webhooks from Bitbucket & GitHub.
// For Bitbucket - the function compares the X-Hook-UUID header with HookID stage variable and checks if there's a match.
// For GitHub - the function signs the request body with a shared secret and compares it to the 'X-Hub-Signature' header.
// The function will allow the request to pass if there's a match and will return 401 ('Unauthorized') otherwise.
const crypto = require('crypto');

exports.handler = function(event, context, callback) {
    console.log('Received event:', JSON.stringify(event, null, 2));

    // Retrieve request parameters from the Lambda function input:
    var headers = event.headers;
    var stageVariables = event.stageVariables;

    // Parse methodArn from event and get the resource
    // Example for methodArn - arn:aws:execute-api:eu-west-1:130217157771:jr7vqbm836/v1/POST/build
    var api_path_from_arn = event.methodArn.split('/')[3];
    var resource = api_path_from_arn ? `/${api_path_from_arn}` : '/';

    // Perform authorization to return the Allow policy for correct parameters and
    // the 'Unauthorized' error, otherwise.

    // For Github requests - sign the request body using the 'GithubSecret' stage variable and compare the signature with
    // the 'X-Hub-Signature' header.
    if (headers['X-Hub-Signature']) {
        var calculatedSig = signRequestBody(stageVariables.GithubSecret, event.body);
        if (headers['X-Hub-Signature'] === calculatedSig) {
            callback(null, generatePolicy('me', 'Allow', resource));
        } else {
            callback("Unauthorized");
        }
    }

    // For Bitbucket requests - compare between the 'X-Hook-UUID' header and the 'HookID' stage variable
    if (headers['X-Hook-UUID'])
        if (headers['X-Hook-UUID'] === stageVariables.HookID) {
            callback(null, generatePolicy('me', 'Allow', resource));
        } else {
            callback("Unauthorized");
        }
    }
}

// Help function to generate an IAM policy
var generatePolicy = function(principalId, effect, resource) {
    // Required output:
    var authResponse = {};
    authResponse.principalId = principalId;
    if (effect && resource) {
        var policyDocument = {};
        policyDocument.Version = '2012-10-17'; // default version
        policyDocument.Statement = [];
        var statementOne = {};
        statementOne.Action = 'execute-api:Invoke'; // default action
        statementOne.Effect = effect;
        statementOne.Resource = resource;
        policyDocument.Statement[0] = statementOne;
        authResponse.policyDocument = policyDocument;
    }
    return authResponse;
}

// this function signs the body variable using the 'key' variable, according to instructions of GitHub
// https://developer.github.com/webhooks/securing/#validating-payloads-from-github
function signRequestBody(key, body) {
  return `sha1=${crypto.createHmac('sha1', key).update(body, 'utf-8').digest('hex')}`;
}
