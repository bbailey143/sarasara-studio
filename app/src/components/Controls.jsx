import {
  Button,
  Label,
  ListBox,
  ListBoxItem,
  Popover,
  Select as AriaSelect,
  SelectValue,
  Slider as AriaSlider,
  SliderOutput,
  SliderThumb,
  SliderTrack,
  TextArea,
  ToggleButton,
} from 'react-aria-components';

/* Shared class strings, so the same control never drifts between panels. */
const FIELD = 'flex flex-col gap-1.5';
const LABEL = 'text-[12.5px] font-medium text-ink';
const VALUE = 'font-mono text-[11.5px] text-ink2 tabular-nums';
const ENDS = 'flex justify-between font-mono text-[10px] text-ink3 tabular-nums';
const INPUT =
  'w-full rounded border border-rule2 bg-panel2 px-2.5 py-1.5 text-[13px] text-ink ' +
  'hover:border-ink3 focus:outline-none';

export const BTN =
  'cursor-pointer rounded border border-rule2 bg-panel2 px-3 py-1.5 text-[12.5px] font-medium ' +
  'text-ink hover:border-ink3 pressed:translate-y-px disabled:cursor-default disabled:opacity-45';

export const BTN_PRIMARY =
  'cursor-pointer rounded border border-pigment bg-pigment px-3 py-1.5 text-[12.5px] font-medium ' +
  'text-onaccent hover:opacity-90 pressed:translate-y-px disabled:cursor-default disabled:opacity-45';

/** A labelled slider with its value, range ends, and a filled track. */
export function Slider({ label, value, onChange, min = 0, max = 1, step = 0.01, format }) {
  const show = format || ((v) => v.toFixed(2));
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <AriaSlider
      className={FIELD}
      value={value}
      onChange={onChange}
      minValue={min}
      maxValue={max}
      step={step}
    >
      <div className="flex items-baseline justify-between gap-2.5">
        <Label className={LABEL}>{label}</Label>
        <SliderOutput className={VALUE}>{show(value)}</SliderOutput>
      </div>
      <SliderTrack className="relative flex h-[22px] w-full items-center">
        <div className="absolute inset-x-0 h-1 rounded-sm border border-rule bg-panel2" />
        <div
          className="absolute left-0 h-1 rounded-sm bg-pigment opacity-55"
          style={{ width: `${pct}%` }}
        />
        <SliderThumb
          className="top-1/2 h-3.5 w-3.5 rounded-full border-2 border-pigment bg-panel
                     shadow-sm dragging:bg-pigment"
        />
      </SliderTrack>
      <div className={ENDS}>
        <span>{show(min)}</span>
        <span>{show(max)}</span>
      </div>
    </AriaSlider>
  );
}

/** A labelled select over `items` of { id, name, version? }. */
export function Select({ label, items, value, onChange }) {
  return (
    <AriaSelect
      className={FIELD}
      selectedKey={value}
      onSelectionChange={(key) => onChange(String(key))}
    >
      <Label className={LABEL}>{label}</Label>
      <Button className={`${INPUT} flex cursor-pointer items-center justify-between gap-2 text-left`}>
        <SelectValue />
        <span aria-hidden="true" className="text-[10px] text-ink3">▾</span>
      </Button>
      <Popover className="min-w-(--trigger-width) overflow-hidden rounded border border-rule2 bg-panel shadow-lg">
        <ListBox className="max-h-72 overflow-y-auto p-1 outline-none" items={items}>
          {(item) => (
            <ListBoxItem
              className="flex cursor-pointer items-baseline justify-between gap-2.5 rounded-sm px-2.5
                         py-1.5 text-[13px] outline-none focused:bg-pigmentsoft selected:font-semibold"
              id={item.id}
              textValue={item.name}
            >
              <span>{item.name}</span>
              {item.version ? (
                <span className="font-mono text-[10px] text-ink3">v{item.version}</span>
              ) : null}
            </ListBoxItem>
          )}
        </ListBox>
      </Popover>
    </AriaSelect>
  );
}

/** A row of mutually exclusive toggles. */
export function ToggleRow({ label, options, value, onChange }) {
  const id = `toggle-${label.replace(/\s+/g, '-').toLowerCase()}`;
  return (
    <div className={FIELD}>
      <span className={LABEL} id={id}>{label}</span>
      <div
        role="group"
        aria-labelledby={id}
        className="flex overflow-hidden rounded border border-rule2"
      >
        {options.map((option) => (
          <ToggleButton
            key={option.id}
            className="flex-1 cursor-pointer border-0 border-r border-rule2 bg-panel2 px-2.5 py-1.5
                       text-[12.5px] text-ink2 last:border-r-0
                       selected:bg-pigment selected:font-semibold selected:text-onaccent"
            isSelected={value === option.id}
            onChange={() => onChange(option.id)}
          >
            {option.name}
          </ToggleButton>
        ))}
      </div>
    </div>
  );
}

export function Notes({ id, label, value, onChange, placeholder, rows = 3 }) {
  return (
    <div className={FIELD}>
      <Label className={LABEL} htmlFor={id}>{label}</Label>
      <TextArea
        id={id}
        rows={rows}
        className={`${INPUT} resize-y text-[12.5px] leading-relaxed`}
        value={value}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
      />
    </div>
  );
}

export { Button };
