interface ChipProps {
  label: string
  onRemove?: () => void
}

export function Chip({ label, onRemove }: ChipProps) {
  return (
    <span className="chip">
      {label}
      {onRemove && (
        <button className="chip-remove" onClick={onRemove} title="Remove">×</button>
      )}
    </span>
  )
}
