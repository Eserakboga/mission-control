# Planet visual assets

All listed source assets are copied into this project and loaded locally. The game does not fetch visual assets at runtime.

## Models and maps

| Project file | Source and credit | Original source | Use |
|---|---|---|---|
| `earth_with_clouds.glb` | NASA Visualization Technology Applications and Development (VTAD), *Earth with Clouds 3D Model* | <https://science.nasa.gov/resource/earth-with-clouds-3d-model/> | Main menu Earth geometry and its NASA surface/cloud imagery |
| `earth_with_clouds_earthClouds_diff.png`, `earth_with_clouds_earth_norm.png` | Diffuse and normal images embedded in the Earth GLB and extracted by Godot's GLB importer; names/content are from the original NASA model. | <https://science.nasa.gov/resource/earth-with-clouds-3d-model/> | Local material dependencies of the imported Earth GLB; the diffuse map also supplies the cloud-mask derivation |
| `earth_blue_marble.jpg` | NASA Earth Observatory, Blue Marble: Next Generation, January global base map (5400 × 2700) | <https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-map/> | Equirectangular Earth image used in 2D globe cards and the launch animation |
| `earth_cloud_mask.png` | Derived from the embedded diffuse map in `earth_with_clouds.glb`; a low-chroma brightness mask isolates cloud-like pixels. It is not an original NASA-delivered cloud layer. | <https://science.nasa.gov/resource/earth-with-clouds-3d-model/> | Independent, slowly rotating cloud shell on the 3D Earth |
| `moon_lro_small.glb` | NASA Goddard Space Flight Center Scientific Visualization Studio; LRO imagery/topography. Credit on source page: NASA GSFC; producer Dan Gallagher (eMITS); data provider Ernie Wright (STC). | <https://svs.gsfc.nasa.gov/14959/> | Moon model in the orbit preview and lunar mission card render |
| `moon_lro_small_Cube_diffuse.png` | Color texture embedded in the NASA LRO GLB and extracted by Godot's GLB importer. | <https://svs.gsfc.nasa.gov/14959/> | Local material dependency of the imported Moon GLB |
| `moon_global_map.jpg` | Derived 2048 × 1024 equirectangular reprojection of the color texture embedded in `moon_lro_small.glb`, sampled through the model's GLB UV coordinates. | <https://svs.gsfc.nasa.gov/14959/> | 2D lunar mission card |
| `mars.glb` | NASA/JPL-Caltech, *Planet Mars, 3D Model* | <https://science.nasa.gov/resource/planet-mars-3d-model/> | Mars model in the orbit preview and Mars mission card render |
| `mars_mars_diff.png`, `mars_mars_norm.png` | Diffuse and normal images embedded in the NASA Mars GLB and extracted by Godot's GLB importer. | <https://science.nasa.gov/resource/planet-mars-3d-model/> | Local material dependencies of the imported Mars GLB |
| `mars_texture_source.tif` | NASA/JPL-Caltech 3D Resources image texture; source page states the map is from Viking images processed at USGS and JPL/Caltech generated planetary maps. | <https://science.nasa.gov/3d-resources/mars/> | Preserved downloaded source map |
| `mars_global_map.jpg` | Derived compact JPEG copy of the 1440 × 720 NASA Mars texture TIFF. | <https://science.nasa.gov/3d-resources/mars/> | 2D Mars mission card |
| `saturn.glb` | NASA Visualization Technology Applications and Development (VTAD), *Saturn 3D Model* | <https://science.nasa.gov/resource/saturn-3d-model/> | Rotating, ringed 3D illustration in the Deep Space mission card; not a mission target |
| `saturn_saturn_diff.png`, `saturn_saturn_rings_25sat_outterRings.png` | Surface and ring textures embedded in the NASA Saturn GLB and extracted by Godot's GLB importer. | <https://science.nasa.gov/resource/saturn-3d-model/> | Local material dependencies of the imported Saturn GLB |

## Usage notes

NASA says its media, including texture maps and polygon data used in 3D models, is generally not subject to U.S. copyright, with exceptions for third-party material and individual credit notices. These files retain the source credits above. NASA names, insignia, and logos are not included. Nothing in the project implies NASA endorsement.

See NASA's current [Media Usage Guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/) and the source page for any item-specific credit or rights notice. Accessed 2026-11-15.
