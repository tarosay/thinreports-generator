"""Builds template.tlf for the table feature test.

The Section Editor cannot create a table item yet, so the template is
generated from this script until the editor supports it.
"""
import io
import json


def text_style(size=10, align='left', valign='middle', color='#000000',
               bold=False, family='IPAGothic'):
    return {
        'font-family': [family],
        'color': color,
        'font-style': ['bold'] if bold else [],
        'text-align': align,
        'vertical-align': valign,
        'letter-spacing': '',
        'font-size': size,
        'line-height-ratio': '',
        'line-height': ''
    }


def text(texts, **kw):
    return {
        'type': 'text',
        'id': '',
        'description': '',
        'display': True,
        'follow-stretch': 'none',
        'texts': texts if isinstance(texts, list) else [texts],
        'style': text_style(**kw),
        'affect-bottom-margin': True
    }


def text_block(item_id, multiple=False, overflow='truncate', **kw):
    style = text_style(**kw)
    style.update({'overflow': overflow, 'word-wrap': 'break-word'})
    return {
        'type': 'text-block',
        'id': item_id,
        'description': '',
        'reference-id': '',
        'value': '',
        'multiple-line': multiple,
        'display': True,
        'format': {'base': '', 'type': ''},
        'follow-stretch': 'none',
        'style': style,
        'affect-bottom-margin': True
    }


def cell(column_id, content=None, col_span=1, row_span=1, background=None,
         pattern=None, padding=None, borders=None):
    style = {'padding': padding or [1, 4, 1, 4]}
    if background:
        style['background-color'] = background
    if pattern:
        style.update(pattern)
    if borders:
        style.update(borders)

    schema = {
        'column-id': column_id,
        'col-span': col_span,
        'row-span': row_span,
        'display': True,
        'style': style
    }
    if content:
        schema['content'] = content
    return schema


HEAD_BG = '#dfe6ee'

table = {
    'type': 'table',
    'id': 'items',
    'x': 0,
    'y': 40,
    'width': 510,
    'height': 92,
    'description': '',
    'display': True,
    'follow-stretch': 'none',
    'affect-bottom-margin': True,
    'style': {
        'border-width': 0.5,
        'border-color': '#333333',
        'border-style': 'solid'
    },
    'columns': [
        {'id': 'name', 'width': 180},
        {'id': 'qty', 'width': 60},
        {'id': 'price', 'width': 90},
        {'id': 'note', 'width': 180}
    ],
    'rows': [
        # Two header rows: "商品名" and "備考" span over both of them,
        # while "数量" and "単価" are grouped under "金額".
        {
            'id': 'head1',
            'type': 'header',
            'height': 22,
            'auto-stretch': False,
            'cells': [
                cell('name', text('商品名', align='center', bold=True), row_span=2, background=HEAD_BG),
                cell('qty', text('金額', align='center', bold=True), col_span=2, background=HEAD_BG),
                cell('note', text('備考', align='center', bold=True), row_span=2, background=HEAD_BG)
            ]
        },
        {
            'id': 'head2',
            'type': 'header',
            'height': 22,
            'auto-stretch': False,
            'cells': [
                cell('qty', text('数量', align='center', bold=True), background=HEAD_BG),
                cell('price', text('単価', align='center', bold=True), background=HEAD_BG)
            ]
        },
        # The body row stretches itself according to the content of the note cell.
        {
            'id': 'detail',
            'type': 'body',
            'height': 24,
            'auto-stretch': True,
            'cells': [
                cell('name', text_block('name')),
                cell('qty', text_block('qty', align='right')),
                cell('price', text_block('price', align='right')),
                cell('note', text_block('note', multiple=True, overflow='expand', valign='top'))
            ]
        },
        {
            'id': 'total',
            'type': 'footer',
            'height': 24,
            'auto-stretch': False,
            'cells': [
                cell('name', text('合計', align='right', bold=True), col_span=2, background='#f2f2f2'),
                cell('price', text_block('total_price', align='right', bold=True), background='#f2f2f2'),
                cell('note',
                     pattern={
                         'background-pattern': 'forward-diagonal',
                         'background-pattern-color': '#9aa7b4',
                         'background-pattern-spacing': 3,
                         'background-pattern-width': 0.4
                     })
            ]
        }
    ]
}

schema = {
    'schema-version': '1.0',
    'last-modified-by': 'table-feature-script',
    'title': 'Table',
    'report': {
        'orientation': 'portrait',
        'paper-type': 'A4',
        'width': 0,
        'height': 0,
        'margin': [30, 40, 30, 40]
    },
    'sections': [
        {
            'id': 'main',
            'type': 'detail',
            'height': 140,
            'display': True,
            'auto-stretch': True,
            'every-page': False,
            'items': [
                {
                    'type': 'text',
                    'id': '',
                    'x': 0,
                    'y': 0,
                    'width': 510,
                    'height': 28,
                    'description': '',
                    'display': True,
                    'follow-stretch': 'none',
                    'texts': ['注文明細'],
                    'style': text_style(size=20, bold=True, valign='top'),
                    'affect-bottom-margin': True
                },
                table
            ]
        }
    ]
}

with io.open('template.tlf', 'w', encoding='utf-8', newline='\n') as f:
    json.dump(schema, f, ensure_ascii=False, indent=2)
    f.write('\n')

print('template.tlf written')
