#!/usr/bin/env python3
"""Validate the authoring document and emit stable, module-independent schema metadata."""
import argparse
import hashlib
import json
import math
import pathlib
import re
import sys
import shutil
try:
    import yaml
except ImportError:
    sys.exit('Input generation requires PyYAML: python3 -m pip install -r game/tools/requirements-input.txt')

# Match the runtime validator's C++ identifier rules.
KEYWORDS = set('alignas alignof and and_eq asm atomic_cancel atomic_commit atomic_noexcept auto bitand bitor bool break case catch char char8_t char16_t char32_t class compl concept const consteval constexpr constinit const_cast continue co_await co_return co_yield decltype default delete do double dynamic_cast else enum explicit export extern false float for friend goto if inline int long mutable namespace new noexcept not not_eq nullptr operator or or_eq private protected public reflexpr register reinterpret_cast requires return short signed sizeof static static_assert static_cast struct switch synchronized template this thread_local throw true try typedef typeid typename union unsigned using virtual void volatile wchar_t while xor xor_eq InputAction InputMap Canis GeneratedInput'.split())

class StrictLoader(yaml.SafeLoader):
    pass

def mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f'Duplicate YAML field: {key}')
        result[key] = loader.construct_object(value_node, deep=deep)
    return result
StrictLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)

def require(condition, message):
    if not condition:
        raise ValueError(message)

def fields(node, allowed, required):
    require(isinstance(node, dict), 'Expected a mapping')
    require(not node.keys() - set(allowed), f'Unknown fields: {node.keys() - set(allowed)}')
    require(set(required) <= node.keys(), f'Missing fields: {set(required) - node.keys()}')

def validate(doc, catalog):
    fields(doc, ('version','maps','reservedIds'), ('version','maps'))
    require(type(doc['version']) is int and doc['version'] == 1, 'Unsupported input version')
    controls = dict(re.findall(r'\{"([^"]+)", \d+, \d+, ActionType::(\w+)\}', catalog))
    ids, names, map_names = set(), set(), set()
    def identity(value):
        require(type(value) is int and 0 < value <= 0xffffffff and value not in ids, f'Duplicate, reserved, or invalid ID: {value}')
        ids.add(value)
    def name(value, seen):
        require(isinstance(value, str) and re.fullmatch('[A-Za-z][A-Za-z0-9_]*',value) and '__' not in value and value not in KEYWORDS and value not in seen, f'Invalid or duplicate C++ name: {value}')
        seen.add(value)
    require(isinstance(doc.get('reservedIds', []), list), 'reservedIds must be a sequence')
    for value in doc.get('reservedIds', []): identity(value)
    require(isinstance(doc['maps'], list), 'maps must be a sequence')
    for m in doc['maps']:
        fields(m, ('id','name','actions'), ('id','name','actions'))
        identity(m['id']); name(m['name'],map_names)
        require(isinstance(m['actions'], list), 'actions must be a sequence')
        for a in m['actions']:
            fields(a, ('id','name','type','bindings'), ('id','name','type','bindings'))
            identity(a['id']); name(a['name'],names)
            require(a['type'] in ('Button','Axis1D','Axis2D'), 'Unknown action type')
            require(isinstance(a['bindings'],list), 'bindings must be a sequence')
            primary_schemes=set()
            for b in a['bindings']:
                fields(b, ('id','scheme','path','parts','deadZone','scale','invert','pressThreshold','releaseThreshold','primaryPrompt','iconOverride'), ('id','scheme','path'))
                identity(b['id'])
                require(b['scheme'] in ('KeyboardMouse','Gamepad'), 'Unknown input scheme')
                require(isinstance(b['path'],str), 'path must be a string')
                def control(path):
                    require(path in controls, f'Unknown control: {path}')
                    require(path.startswith('Gamepad/') == (b['scheme'] == 'Gamepad'), f'Scheme mismatch: {path}')
                    return controls[path]
                if b['path'].startswith('Composite/'):
                    dimension = b['path'].removeprefix('Composite/')
                    require(dimension in ('Axis1D','Axis2D') and a['type'] == dimension, 'Composite/action type mismatch')
                    expected = {'up','down','left','right'} if dimension == 'Axis2D' else {'negative','positive'}
                    require(isinstance(b.get('parts'),dict) and set(b['parts']) == expected, 'Invalid composite parts')
                    for path in b['parts'].values(): require(control(path) == 'Button', 'Composite parts must be buttons')
                else:
                    require(not b.get('parts'), 'Simple binding cannot have parts')
                    typ = control(b['path'])
                    require(typ == a['type'] or (a['type'] == 'Button' and typ == 'Axis1D'), 'Binding/action type mismatch')
                for field, default in [('deadZone',0),('scale',1),('pressThreshold',0.5),('releaseThreshold',0.4)]:
                    val = b.get(field,default)
                    require(type(val) in (int,float) and math.isfinite(val), f'Invalid {field}')
                require(0 <= b.get('deadZone',0) < 1, 'Invalid dead zone')
                require(0 <= b.get('releaseThreshold',0.4) < b.get('pressThreshold',0.5) <= 1, 'Invalid thresholds')
                require(type(b.get('invert',False)) is bool, 'invert must be boolean')
                require(type(b.get('primaryPrompt',False)) is bool, 'primaryPrompt must be boolean')
                require(isinstance(b.get('iconOverride',''),str), 'iconOverride must be a path string')
                if b.get('primaryPrompt',False):
                    require(b['scheme'] not in primary_schemes, 'Multiple primary prompts for one scheme')
                    primary_schemes.add(b['scheme'])
    return doc

def generate(doc):
    maps = sorted(doc['maps'], key=lambda m:m['id'])
    actions = sorted([(m['id'],a) for m in maps for a in m['actions']], key=lambda pair:pair[1]['id'])
    schema = {'maps':[(m['id'],m['name']) for m in maps], 'actions':[(m,a['id'],a['name'],a['type']) for m,a in actions]}
    signature = hashlib.sha256(json.dumps(schema,sort_keys=True).encode()).hexdigest()
    lines = ['// Generated. Edit the input asset, not this file.', '#pragma once', '#include <Canis/InputActions.hpp>', 'enum class InputAction : uint32_t {']
    lines += [f"    {a['name']} = {a['id']}u," for _,a in actions]
    lines += ['};', 'enum class InputMap : uint32_t {']
    lines += [f"    {m['name']} = {m['id']}u," for m in maps]
    lines += ['};', 'namespace Canis {', 'template<> struct InputActionEnum<::InputAction> : std::true_type {};', 'template<> struct InputMapEnum<::InputMap> : std::true_type {};', '}', 'namespace GeneratedInput {', f'inline constexpr const char* Signature = "{signature}";', 'inline Canis::InputDocument Schema() {', '    Canis::InputDocument document;']
    lines += [f'    document.maps.push_back({{{m["id"]}u, "{m["name"]}"}});' for m in maps]
    lines += [f'    document.actions.push_back({{{a["id"]}u, {m}u, "{a["name"]}", Canis::ActionType::{a["type"]}, {{}}}});' for m,a in actions]
    lines += ['    return document;', '}', '}', '']
    return '\n'.join(lines)

def write_changed(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_text() != text: path.write_text(text)

def steam_manifest(doc, configurations=None, root_name='Action Manifest'):
    """Every action name is unique, including copies used by simultaneous-map layers."""
    def q(value): return json.dumps(str(value),ensure_ascii=False)
    def block(name, contents, indent=0):
        pad='    '*indent
        return [pad+q(name),pad+'{']+[pad+'    '+line for line in contents]+[pad+'}']
    maps=sorted(doc['maps'],key=lambda m:m['id'])
    def action_set(m, suffix='', parent=None):
        lines=[q('title')+' '+q('#map_'+str(m['id']))]
        if parent is not None:
            lines += ['"legacy_set" "0"','"set_layer" "1"','"parent_set_name" '+q('map_'+str(parent))]
        for typ,group in [('Button','Button'),('Axis1D','AnalogTrigger'),('Axis2D','StickPadGyro')]:
            entries=[]
            for a in sorted(m['actions'],key=lambda a:a['id']):
                if a['type']!=typ: continue
                name='action_'+str(a['id'])+suffix
                title='#action_'+str(a['id'])
                if typ=='Axis2D':
                    mouse=any(b['path']=='Mouse/Delta' for b in a['bindings'])
                    entries+=block(name,['"title" '+q(title),'"input_mode" '+q('absolute_mouse' if mouse else 'joystick_move')])
                else: entries.append(q(name)+' '+q(title))
            lines+=block(group,entries)
        return lines
    body=[]
    if root_name=='Action Manifest':
        configs=[]
        for controller,path in sorted((configurations or {}).items()):
            configs+=block(controller,block('0',['"path" '+q(path)]))
        body+=block('configurations',configs)
    sets=[];layers=[];localization=[]
    for m in maps:
        sets+=block('map_'+str(m['id']),action_set(m))
        localization.append(q('map_'+str(m['id']))+' '+q(m['name']))
        for a in m['actions']:localization.append(q('action_'+str(a['id']))+' '+q(a['name']))
        for parent in maps:
            if parent['id']!=m['id']:
                layers+=block('layer_'+str(parent['id'])+'_'+str(m['id']),action_set(m,'_on_'+str(parent['id']),parent['id']))
    body+=block('actions',sets)+block('action_layers',layers)+block('localization',block('english',localization))
    return '\n'.join(block(root_name,body))+'\n'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input',required=True,type=pathlib.Path)
    parser.add_argument('--catalog',required=True,type=pathlib.Path)
    parser.add_argument('--output',required=True,type=pathlib.Path)
    parser.add_argument('--steam-dir',type=pathlib.Path)
    parser.add_argument('--configurations',type=pathlib.Path)
    args = parser.parse_args()
    try:
        document = validate(yaml.load(args.input.read_text(),Loader=StrictLoader), args.catalog.read_text())
        write_changed(args.output,generate(document))
        if args.steam_dir:
            configurations={}
            if args.configurations:
                configurations=yaml.load(args.configurations.read_text(),Loader=StrictLoader) or {}
                require(isinstance(configurations,dict),'Steam configurations must map device names to file paths')
                for device,path in configurations.items():
                    require(isinstance(device,str) and re.fullmatch('controller_[a-z0-9_]+',device),'Invalid Steam controller type')
                    require(isinstance(path,str) and not pathlib.Path(path).is_absolute() and '..' not in pathlib.Path(path).parts,'Unsafe Steam configuration path')
                    source=args.configurations.parent/path
                    require(source.is_file(),f'Missing recommended Steam configuration: {source}')
                    destination=args.steam_dir/path
                    destination.parent.mkdir(parents=True,exist_ok=True)
                    if not destination.exists() or source.read_bytes()!=destination.read_bytes(): shutil.copyfile(source,destination)
            write_changed(args.steam_dir/'input_manifest.vdf',steam_manifest(document,configurations))
            write_changed(args.steam_dir/'game_actions.vdf',steam_manifest(document,root_name='In Game Actions'))
    except (ValueError,TypeError,KeyError,OSError,yaml.YAMLError) as error:
        sys.exit(f'Input asset validation failed: {error}')
if __name__ == '__main__': main()
