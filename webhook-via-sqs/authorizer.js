exports.handler = function(event, context, callback) {
    console.log('Received event:', JSON.stringify(event, null, 2));

    // A REQUEST authorizer that compares the X-Hook-UUID header with
    // HookID stage variable, and allow or deny the request accordingly.

    // Retrieve request parameters from the Lambda function input:
    var headers = event.headers;
    var stageVariables = event.stageVariables;

    // Parse methodArn from event and get the resource
    // Example for methodArn - arn:aws:execute-api:eu-west-1:130917157771:jr7vqbm836/v1/POST/build
    var api_path_from_arn = event.methodArn.split('/')[3];
    var resource = api_path_from_arn ? `/${api_path_from_arn}` : '/';

    // Perform authorization to return the Allow policy for correct parameters and
    // the 'Unauthorized' error, otherwise.

    if (headers['X-Hook-UUID'] === stageVariables.HookID) {
        callback(null, generatePolicy('me', 'Allow', resource));
    }  else {
        callback("Unauthorized");
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
