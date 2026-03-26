export function TenantRequiredBanner() {
  return (
    <div className="alert alert-warning" role="alert">
      <strong>No tenant selected.</strong> Use the tenant switcher in the header to select a
      tenant and view its data.
    </div>
  )
}
