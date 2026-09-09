"""Run with python3 -m unittest discover -s game/tests."""
import pathlib
import subprocess
import tempfile
import unittest

GENERATOR = pathlib.Path(__file__).resolve().parents[1] / 'cmake/GenerateTags.cmake'


class TagGenerationTests(unittest.TestCase):
    def generate(self, settings, success=True):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            source, output = root / 'project.canis', root / 'Tags.generated.hpp'
            source.write_text(settings)
            result = subprocess.run([
                'cmake', f'-DSETTINGS_FILE={source}', f'-DOUTPUT_FILE={output}',
                '-P', str(GENERATOR),
            ], capture_output=True, text=True)
            if success:
                self.assertEqual(result.returncode, 0, result.stderr)
                return output.read_text()
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())

    def test_block_and_flow_sequences(self):
        block = self.generate('tags:\n  - Player\n  - "Enemy" # comment\nvolume: 1\n')
        flow = self.generate("tags: [Player, 'Enemy']\n")
        self.assertEqual(block, flow)
        self.assertIn('case Tags::Player: return "Player";', block)

    def test_reordering_keeps_names(self):
        for sequence in ('[Player, Enemy]', '[Enemy, Player]'):
            output = self.generate(f'tags: {sequence}\n')
            for tag in ('Player', 'Enemy'):
                self.assertIn(f'case Tags::{tag}: return "{tag}";', output)

    def test_numeric_ids_match_runtime_hash(self):
        for sequence in ('[Player, Enemy]', '[Enemy, Player, Pickup]'):
            generated = self.generate(f'tags: {sequence}\n')
            with tempfile.TemporaryDirectory() as directory:
                root = pathlib.Path(directory)
                (root / 'Tags.generated.hpp').write_text(generated)
                source = root / 'check.cpp'
                source.write_text('''#include "Tags.generated.hpp"
#include <type_traits>
static_assert(std::is_same_v<std::underlying_type_t<Tags>, Canis::TagId>);
static_assert(ToTagId(Tags::None) == 0);
static_assert(ToTagId(Tags::Player) == 0x333dc56ddffd8ea0ull);
static_assert(ToTagId(Tags::Enemy) == Canis::TagIdFromName("Enemy"));
''')
                include = GENERATOR.parents[2] / 'canis/include'
                result = subprocess.run(['c++', '-std=c++20', '-fsyntax-only',
                                         '-I', str(include), str(source)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_empty_and_legacy_settings(self):
        self.assertEqual(self.generate('tags: []\n'), self.generate('volume: 1\n'))

    def test_invalid_identifiers(self):
        for tag in ('None', 'class', '123Player', 'Player-Enemy', 'Player Enemy', 'A__B'):
            with self.subTest(tag=tag):
                self.generate(f'tags:\n  - {tag}\n', success=False)

    def test_duplicates(self):
        self.generate('tags: [Player, Player]\n', success=False)
        self.generate('tags: [Player]\ntags: [Enemy]\n', success=False)

    def test_wrong_type(self):
        self.generate('tags: Player\n', success=False)
        self.generate('tags:\n  Player: 1\n', success=False)


if __name__ == '__main__':
    unittest.main()
