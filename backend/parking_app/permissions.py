from oauth2_provider.contrib.rest_framework import TokenHasScope


class TokenHasAnyScope(TokenHasScope):
    """
    The request is authenticated as a user, and the token used has at least one of the required scopes.
    """
    def has_permission(self, request, view):
        token = request.auth
        if not token:
            return False

        required_scopes = getattr(view, 'required_scopes', [])
        return any(scope in token.scope.split() for scope in required_scopes)