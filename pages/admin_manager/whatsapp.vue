<template>
  <div class="whatsapp-page">
    <div class="page-header"><div><h1>WhatsApp Notification Setup</h1><div class="desc">Link the official hospital WhatsApp account used for patient treatment reminders.</div></div></div>
    <WhatsAppGatewayCard />
    <div class="card card-pad setup-note">
      <h3>Service requirement</h3>
      <p>The secure WhatsApp worker must be running on the clinic server. When it starts without a saved session, the QR code appears above. After scanning, the connection is remembered and this page changes to Connected.</p>
    </div>
  </div>
</template>
<style scoped>.whatsapp-page{max-width:880px;margin:auto}.setup-note{margin-top:16px}.setup-note h3{font-size:13px}.setup-note p{margin-top:6px;color:var(--text-600);font-size:12px;line-height:1.55}</style>
