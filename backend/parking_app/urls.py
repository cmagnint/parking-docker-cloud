from django.urls import path
from . import views

app_name = 'parking_app'

urlpatterns = [

    #=========================================================================================
    #================================ SUPERADMIN =============================================
    #=========================================================================================
    path('administrar_sociedad/', views.AdministrarSociedadView.as_view(), name='administrar_sociedad_list'),
    path('administrar_sociedad/<int:sociedad_id>/', views.AdministrarSociedadView.as_view(), name='administrar_sociedad_detail'),
    path('consultar_registros_sociedad/', views.ConsultarRegistrosSociedadSuperAdminView.as_view(), name='consultar_registros_sociedad'),  # NUEVA

    #=========================================================================================
    #================================ ADMIN ==================================================
    #=========================================================================================
    
    path('gestion_registros/', views.GestionRegistrosView.as_view(), name='gestion_registros'),  
    path('usuarios/<int:id_sociedad>/', views.UsuariosApiView.as_view(), name='usuarios_list_create'),
    path('usuarios/<int:id_sociedad>/<str:rut>/', views.UsuariosApiView.as_view(), name='usuarios_detail'),
    path('parametros/<int:id_sociedad>/', views.ParametrosApiView.as_view(), name='parametros'),


    #=========================================================================================
    #================================ LOGIN ==================================================
    #=========================================================================================
    path('login/',  views.LoginView.as_view(), name='login'),
    path('check_token/', views.CheckTokenView.as_view(), name='check_token'),  
    path('verificar_codigo/', views.VerificarCodigoView.as_view(), name='verificar_codigo'),
    path('generar_codigo/',  views.GenerarCodigoView.as_view(), name='generar_codigo'),
    path('cambiar_contrasena/',  views.CambiarContrasenaView.as_view(), name='cambiar_contrasena'),

    #=========================================================================================
    #================================ ESTACIONAMIENTO ========================================
    #=========================================================================================
    path('registro_inicial/',  views.RegistroInicialView.as_view(), name='registro_inicial'),
    path('registro_final/',  views.RegistroFinalView.as_view(), name='registro_final'),
    path('obtener_registros_del_dia/', views.ObtenerRegistrosDelDiaView.as_view(), name='obtener_registros_del_dia'),
    path('pedir_historial/', views.PedirHistorialView.as_view(), name='pedir_historial'),
    path('enviar_csv/', views.EnviarCSVView.as_view(), name='enviar_csv'),
    path('enviar_csv_servicios/', views.EnviarCSVServiciosView.as_view(), name='enviar_csv_servicios'),
    path('pedir_correos/', views.PedirCorreosView.as_view(), name='pedir_correos'),
    path('clientes/', views.ClientesRegistradosView.as_view(), name='clientes-list'),
    path('clientes/<int:pk>/', views.ClientesRegistradosView.as_view(), name='clientes-detail'),
    path('servicios/', views.ServiciosView.as_view(), name='servicios-list'),
    path('servicios/<int:pk>/', views.ServiciosView.as_view(), name='servicios-detail'),
    path('registro_servicios/', views.RegistroServiciosView.as_view(), name='servicios-list'),
    path('registro_servicios/<int:pk>/', views.RegistroServiciosView.as_view(), name='servicios-detail'),
    path('clientes_servicios/', views.ClientesServiciosView.as_view(), name='clientes-servicios-list'),
    path('clientes_servicios/<int:pk>/', views.ClientesServiciosView.as_view(), name='clientes-servicios-detail'),
    path('tipos_vehiculos/', views.TipoVehiculoView.as_view(), name='tipos_vehiculos'),
]
