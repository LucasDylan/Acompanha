# ── flutter_stripe / Stripe Android SDK ──────────────────────────────────────
# The Stripe SDK references push-provisioning classes (add card to Google Pay
# wallet) that are NOT bundled, which makes R8 fail the release build with
# "Missing class com.stripe.android.pushProvisioning.*". We don't use push
# provisioning, so suppress those warnings and keep the Stripe/RN-stripe code.
-dontwarn com.stripe.android.pushProvisioning.**
-keep class com.stripe.android.pushProvisioning.** { *; }
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**
