'use strict'

module.exports = function (config, context) {
    return {
        register_middlewares: function (app, auth, storage) {
            app.use(function (req, res, next) {
                if (req.headers && req.headers.authorization) {
                    // Handle Bearer token format from npm
                    if (req.headers.authorization.startsWith('Bearer ')) {
                        const token = req.headers.authorization.slice(7);
                        context.logger.trace(`token-to-user: received bearer token: ${token}`);

                        if (token === config.token) {
                            // Convert to Basic auth with credentials from config
                            context.logger.trace(`token-to-user: authenticated token and now forwarding as basic auth with username '${config.username}' and password '${config.password}'`);

                            req.headers.authorization = `Basic ${Buffer.from(`${config.username}:${config.password}`).toString('base64')}`;
                        }
                    }
                }

                next();
            });
        }
    };
};
