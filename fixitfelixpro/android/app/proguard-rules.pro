# Stripe — push-provisioning classes are referenced by flutter_stripe but
# only exist on the tap-to-pay add-on artifact (which we don't ship). Silence
# R8 so the release bundle compiles.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**
