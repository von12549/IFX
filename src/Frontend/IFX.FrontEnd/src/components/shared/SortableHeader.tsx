type Props = {
  label: string
  col: string
  sortCol: string
  sortDir: 'asc' | 'desc'
  onSort: (col: string) => void
}

export function SortableHeader({ label, col, sortCol, sortDir, onSort }: Props) {
  const active = sortCol === col
  return (
    <th className="sortable-th" onClick={() => onSort(col)}>
      {label}
      <span className={`sort-icon${active ? ' sort-active' : ''}`}>
        {active ? (sortDir === 'asc' ? '↑' : '↓') : '↕'}
      </span>
    </th>
  )
}
