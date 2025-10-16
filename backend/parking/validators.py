from oauth2_provider.oauth2_validators import OAuth2Validator

class CustomOAuth2Validator(OAuth2Validator):
    def save_bearer_token(self, token, request, *args, **kwargs):
        if request.user.is_superuser:
            token['scope'] = 'superadmin_access'
        elif request.user.is_admin:
            token['scope'] = 'admin'
        else:
            token['scope'] = 'write'
        return super().save_bearer_token(token, request, *args, **kwargs)