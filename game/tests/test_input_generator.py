import copy
import importlib.util
import pathlib
import tempfile
import unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('generator', ROOT/'game/tools/generate_input_actions.py')
g=importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
class GeneratorTests(unittest.TestCase):
    def setUp(self):
        self.doc=g.yaml.load((ROOT/'project_settings/input.canis').read_text(),Loader=g.StrictLoader)
        self.catalog=(ROOT/'canis/include/Canis/InputControls.inl').read_text()
    def test_determinism_and_stable_ids(self):
        a=g.generate(g.validate(self.doc,self.catalog))
        self.doc['maps'].reverse()
        for m in self.doc['maps']:m['actions'].reverse()
        self.assertEqual(a,g.generate(g.validate(self.doc,self.catalog)))
        with tempfile.TemporaryDirectory() as directory:
            path=pathlib.Path(directory)/'generated.hpp'
            g.write_changed(path,a); stamp=path.stat().st_mtime_ns
            g.write_changed(path,a); self.assertEqual(stamp,path.stat().st_mtime_ns)
    def test_binding_changes_preserve_schema(self):
        a=g.generate(self.doc)
        self.doc['maps'][0]['actions'][0]['bindings'][0]['path']='Keyboard/Enter'
        self.assertEqual(a,g.generate(g.validate(self.doc,self.catalog)))
        self.doc['maps'][0]['actions'][0]['name']='Leap'
        b=g.generate(g.validate(self.doc,self.catalog))
        self.assertIn('Leap = 1001u',b); self.assertNotEqual(a,b)
    def test_reject_invalid_assets(self):
        for field,value in [('id',0),('name','class'),('name','_Reserved'),('name','bad__name'),('type','Vector3')]:
            doc=copy.deepcopy(self.doc);doc['maps'][0]['actions'][0][field]=value
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):g.validate(doc,self.catalog)
        for field,value in [('id',1001),('path','Keyboard/NotAKey'),('scheme','Touch'),('deadZone',1),('scale',float('nan')),('releaseThreshold',0.9)]:
            doc=copy.deepcopy(self.doc);doc['maps'][0]['actions'][0]['bindings'][0][field]=value
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):g.validate(doc,self.catalog)
    def test_steam_export_uses_unique_stable_names(self):
        import re
        manifest=g.steam_manifest(self.doc)
        self.assertIn('"map_100"',manifest)
        self.assertIn('"action_1001"',manifest)
        self.assertIn('"action_1001_on_101"',manifest)
        self.assertIn('"absolute_mouse"',manifest)
        names=re.findall(r'^\s*"(action_[0-9]+(?:_on_[0-9]+)?)"',manifest,re.M)
        # Localization repeats base tokens once; actual definition names remain unique.
        actions_section=manifest.split('"localization"')[0]
        definitions=re.findall(r'^\s*"(action_[0-9]+(?:_on_[0-9]+)?)"',actions_section,re.M)
        self.assertEqual(len(definitions),len(set(definitions)))
        self.doc['maps'][0]['actions'][0]['name']='Leap'
        self.assertIn('"action_1001"',g.steam_manifest(self.doc))
    def test_reject_duplicate_yaml_fields(self):
        with self.assertRaises(ValueError):g.yaml.load('version: 1\nversion: 2',Loader=g.StrictLoader)
if __name__=='__main__':unittest.main()
