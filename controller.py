import os
import re

import utils


class Pipeline:

    _engine = None

    max_concurrent_jobs = 0
    target_file_count_per_worker = 100
    files = []
    linked_files = dict()
    camera = ""
    plugins_directory = ""
    threed = 0
    calibration = ""
    post_processing_type = ""
    lateral_uncertainty = 0
    scale_bar_enabled = 0

    size_map = dict()
    batch_map = dict()
    max_batch_count = 0
    file_index = 0
    batch_counter = 0

    def __init__(self, engine):
        self._engine = engine
        return

    def validate_working_directories(self):
        working_directory = self._engine.get_file_system().get_working_directory()

        files = []
        # for file in next(os.walk(self._engine.get_file_system().get_source_directory()))[2]:
        for root, dirs, files_list in os.walk(self._engine.get_file_system().get_source_directory()):
            for file in files_list:
                if file.endswith(".ome.tif") or file.endswith(".ome.tiff"):
                    files.append(os.path.join(root, file))

        if len(files) == 0:
            self._engine.error("No valid source files found.")
            return False

        self.files = files

        # Search for file groups
        self.linked_files = dict()
        counter = 0
        for file in files:
            root_file = file.replace(".ome.tiff", "").replace(".ome.tif", "")

            if re.search(r'_\d+$', root_file):
                continue

            similar_files = [file]
            for file2 in files:
                if root_file.startswith(root_file) and root_file != file2:
                    similar_files.append(file2)

            self.linked_files[counter] = similar_files
            counter += 1

        # Allow optional parameters overriding using configuration file
        parameters_file = os.path.join(working_directory, "parameters.json")
        if os.path.isfile(parameters_file):
            raw_parameters = utils.load_json(parameters_file)

            if "max_concurrent_jobs" in raw_parameters:
                self.max_concurrent_jobs = raw_parameters["max_concurrent_jobs"]

            if "target_file_count_per_worker" in raw_parameters:
                self.target_file_count_per_worker = raw_parameters["target_file_count_per_worker"]

            if "camera" in raw_parameters:
                self.camera = raw_parameters["camera"]

            if "plugins_directory" in raw_parameters:
                self.plugins_directory = raw_parameters["plugins_directory"]

            else:
                self._engine.error("Your parameters file must contain a value for plugins_directory pointing to the folder containing the ThunderSTORM ImageJ plugin")
                return False

            if "threed" in raw_parameters:
                if raw_parameters["threed"]:
                    self.threed = 1

                    if "calibration_file" in raw_parameters:
                        self.calibration = raw_parameters["calibration_file"]

                    else:
                        self._engine.error("A calibration file must be provided for 3d localisation")
                        return False

                else:
                    self.threed = 0
            else:
                self.threed = 0

            if "post_processing_type" in raw_parameters:
                self.post_processing_type = raw_parameters["post_processing_type"]
            else:
                self.post_processing_type = "DRIFT"

            if "lateral_uncertainty" in raw_parameters:
                self.lateral_uncertainty = raw_parameters["lateral_uncertainty"]
            else:
                self.lateral_uncertainty = 50

            if "scale_bar_enabled" in raw_parameters:
                tmp = raw_parameters["scale_bar_enabled"]
                if isinstance(tmp, str) and (tmp == "0" or tmp == "1"):
                    self.scale_bar_enabled = tmp

                elif isinstance(tmp, bool):
                    self.scale_bar_enabled = str(int(tmp))

                else:
                    self.scale_bar_enabled = "0"

        else:
            self._engine.error("No parameters file found - this is a requirement to run the pipeline. JSON properties must include a value for the plugins_directory containing the ThunderSTORM plugin.")
            return False

        return True

    def get_target_file_count(self):
        return self.target_file_count_per_worker

    def get_files(self):
        return self.files

    def get_linked_files(self):
        return self.linked_files

    def get_size_map_value(self, file):
        return self.size_map[file]

    def save_size_map(self, file, value):
        self.size_map[file] = value

    def get_batching_map_value(self, file):
        return self.batch_map[file]

    def save_batching_map(self, file, size):
        self.batch_map[file] = size

    def get_total_batches(self):
        return self.max_batch_count

    def update_total_batches(self, count):
        self.max_batch_count = self.max_batch_count + count

    def get_file_index(self):
        return self.file_index

    def set_file_index(self, index):
        self.file_index = index

    def get_batch_counter(self):
        return self.batch_counter

    def set_batch_counter(self, counter):
        self.batch_counter = counter

    def get_plugins_directory(self):
        return self.plugins_directory

    def get_camera(self):
        return self.camera

    def get_threed(self):
        return self.threed

    def get_calibration(self):
        return self.calibration

    def get_post_processing_type(self):
        return self.post_processing_type

    def get_lateral_uncertainty(self):
        return self.lateral_uncertainty

    def get_scale_bar_enabled(self):
        return self.scale_bar_enabled


class PipelineStep:
    parameter_string = ""
    _script = None
    _pipeline = None

    def __init__(self, script, pipeline):
        self._script = script
        self._pipeline = pipeline

    def get_script(self):
        return self._script

    def get_pipeline(self):
        return self._pipeline

    def do_before(self, engine):
        pass

    def map_arguments(self, engine, batch_number):
        pass

    def do_after(self, engine):
        pass


class CameraGatherer(PipelineStep):
    def __init__(self, pipeline):
        super().__init__(os.path.join(os.path.dirname(os.path.realpath(__file__)), "runnables", "CameraGatherer.sh"), pipeline)

    def do_before(self, engine):
        self.parameter_string += " -c=" + self.get_pipeline().get_camera()
        self.parameter_string += " -w=" + engine.get_file_system().get_working_directory()

    def map_arguments(self, engine, batch_number):
        # Note this should only be run on one file as we ASSUME that all files use the same camera
        self.parameter_string += " -f=" + self.get_pipeline().get_files()[batch_number]
        self.parameter_string += " -o=" + self.get_pipeline().get_files()[batch_number].replace(".ome.tiff", "_props.sh").replace(".ome.tif", "_props.sh")
        return self.parameter_string


class TiffSizeCalculator(PipelineStep):
    def __init__(self, pipeline):
        super().__init__(os.path.join(os.path.dirname(os.path.realpath(__file__)), "runnables", "TiffSizeCalculator.sh"), pipeline)

    def map_arguments(self, engine, batch_number):
        dependent_files = self.get_pipeline().get_linked_files()[batch_number]
        filename = os.path.basename(dependent_files[0]).replace(".ome.tiff", "").replace(".ome.tif", "")

        file_string = " -f="
        for file in dependent_files:
            file_string = file_string + file + ","
        self.parameter_string = file_string[:-1]

        self.parameter_string += " -w=" + os.path.join(engine.get_file_system().get_working_directory(), filename)
        self.parameter_string += " -t=" + os.path.join(engine.get_file_system().get_working_directory(), filename + "_count.txt")
        return self.parameter_string

    def do_after(self, engine):
        # Map files to tiff stack size
        for index, files in self.get_pipeline().get_linked_files():
            source_file = os.path.join(engine.get_file_system().get_working_directory(), os.path.basename(files[0]).replace(".ome.tiff", "_count.txt").replace(".ome.tif", "_count.txt"))
            with open(source_file) as f:
                value = int(f.readline())

                # Calculate how many concurrent processes should be acting on this file
                div = value // self.get_pipeline().get_target_file_count()
                rem = value % self.get_pipeline().get_target_file_count()
                if rem > 0:
                    div += 1

                self.get_pipeline().save_size_map(index, value)
                self.get_pipeline().save_batching_map(index, div)
                self.get_pipeline().update_total_batches(div)

        self.get_pipeline().set_file_index(0)
        self.get_pipeline().set_batch_counter(0)


class LocalisationRunner(PipelineStep):
    def __init__(self, pipeline):
        super().__init__(os.path.join(os.path.dirname(os.path.realpath(__file__)), "runnables", "RunLocalisation.sh"), pipeline)

    def do_before(self, engine):
        self.parameter_string += " -w=" + engine.get_file_system().get_working_directory()
        self.parameter_string += " -custom=" + self.get_pipeline().get_plugins_directory()
        self.parameter_string += " -s=" + os.path.join(os.path.dirname(os.path.realpath(__file__)), "macros", "localisation.ijm")
        self.parameter_string += " -threed=" + str(self.get_pipeline().get_threed())

        calib = self.get_pipeline().get_calibration()
        if calib != "":
            self.parameter_string += " -calibration=" + calib

    def map_arguments(self, engine, batch_number):
        file_counter = self.get_pipeline().get_file_index()
        file = self.get_pipeline().get_linked_files()[file_counter][0]  # Only pass on the root stack
        filename = os.path.basename(file).replace(".ome.tiff", "").replace(".ome.tif", "")
        dependent_files = self.get_pipeline().get_linked_files()[batch_number]

        start_index = self.get_pipeline().get_batch_counter() + 1
        step_size = self.get_pipeline().get_batching_map_value(file_counter)
        end_index = self.get_pipeline().get_size_map_value(file_counter) + 1

        if start_index == step_size:
            file_counter += 1
            self.get_pipeline().set_file_index(file_counter)
            self.get_pipeline().set_batch_counter(0)
        else:
            self.get_pipeline().set_batch_counter(start_index)

        parameter_string = self.parameter_string
        parameter_string += " -f=" + file
        parameter_string += " -start=" + str(start_index)
        parameter_string += " -step=" + str(step_size)
        parameter_string += " -end=" + str(end_index)
        parameter_string += " -target_folder=" + os.path.join(engine.get_file_system().get_working_directory(), filename)
        parameter_string += " -camera=" + file.replace(".ome.tiff", "_props.sh").replace(".ome.tif", "_props.sh")

        file_string = " -all_linked_files="
        for file in dependent_files:
            file_string = file_string + file + ","
        parameter_string += file_string[:-1]

        return parameter_string


class CSVMerger(PipelineStep):
    def __init__(self, pipeline):
        super().__init__(os.path.join(os.path.dirname(os.path.realpath(__file__)), "runnables", "CSVMerger.sh"), pipeline)

    def do_before(self, engine):
        self.parameter_string += " -custom=" + self.get_pipeline().get_plugins_directory()
        self.parameter_string += " -s=" + os.path.join(os.path.dirname(os.path.realpath(__file__)), "macros", "post_process.ijm")
        self.parameter_string += " -threed=" + str(self.get_pipeline().get_threed())
        self.parameter_string += " -type=" + self.get_pipeline().get_post_processing_type()
        self.parameter_string += " -lateral=" + str(self.get_pipeline().get_lateral_uncertainty())
        self.parameter_string += " -output=" + engine.get_file_system().get_working_directory()
        self.parameter_string += " -scale=" + engine.get_pipeline().get_scale_bar_enabled()

        calib = self.get_pipeline().get_calibration()
        if calib != "":
            self.parameter_string += " -calibration=" + calib

    def map_arguments(self, engine, batch_number):
        file = self.get_pipeline().get_linked_files()[batch_number][0]
        filename = os.path.basename(file).replace(".ome.tiff", "").replace(".ome.tif", "")

        parameter_string = self.parameter_string
        parameter_string += " -f=" + file
        parameter_string += " -target_folder=" + os.path.join(engine.get_file_system().get_working_directory(), filename)
        parameter_string += " -camera=" + file.replace(".ome.tiff", "_props.sh").replace(".ome.tif", "_props.sh")

        return parameter_string


class Cleanup(PipelineStep):
    def __init__(self, pipeline):
        super().__init__(os.path.join(os.path.dirname(os.path.realpath(__file__)), "runnables", "Cleanup.sh"), pipeline)

    def map_arguments(self, engine, batch_number):
        file = self.get_pipeline().get_linked_files()[batch_number][0]
        filename = os.path.basename(file).replace(".ome.tiff", "").replace(".ome.tif", "")

        parameter_string = self.parameter_string
        parameter_string += " -s=" + os.path.join(engine.get_file_system().get_working_directory(), filename)
        parameter_string += " -o=" + engine.get_file_system().get_output_directory()
        parameter_string += " -f=" + filename

        return parameter_string


def execute_pipeline(engine):
    engine.info("Welcome to the STORM processing pipeline.")
    pipeline = Pipeline(engine)
    if not pipeline.validate_working_directories():
        engine.error("Failed to validate the working directory.")
        return False

    # Assess the camera manufacturer
    if not engine.submit_chunk_and_wait_for_execution(len(pipeline.files), pipeline.max_concurrent_jobs, CameraGatherer(pipeline)):
        engine.error("Failed to assess the detector.")
        return False

    # Calculate tiff stack size for each tiff present
    if not engine.submit_chunk_and_wait_for_execution(len(pipeline.linked_files), pipeline.max_concurrent_jobs, TiffSizeCalculator(pipeline)):
        engine.error("Failed to run the tiff stack size calculator")
        return False

    # Loop through our fov's and perform thunderstorm on each
    if not engine.submit_chunk_and_wait_for_execution(pipeline.get_total_batches(), pipeline.max_concurrent_jobs, LocalisationRunner(pipeline)):
        engine.error("Failed to execute the STORM runner.")
        return False

    # Loop through our files
    if not engine.submit_chunk_and_wait_for_execution(len(pipeline.linked_files), pipeline.max_concurrent_jobs, CSVMerger(pipeline)):
        engine.error("Failed to execute post processing")
        return False

    # Loop through our files
    if not engine.submit_chunk_and_wait_for_execution(len(pipeline.files), pipeline.max_concurrent_jobs, Cleanup(pipeline)):
        engine.error("Failed to execute Cleanup")
        return False

