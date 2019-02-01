import os

import utils


class Pipeline:

    _engine = None

    max_concurrent_jobs = 0
    target_file_count_per_worker = 100
    files = []
    camera = ""
    plugins_directory = ""
    threed = 0
    calibration = ""

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
        for file in next(os.walk(self._engine.get_file_system().get_source_directory()))[2]:
            if file.endswith(".ome.tif") or file.endswith(".ome.tiff"):
                files.append(file)

        if len(files) == 0:
            self._engine.error("No valid source files found.")
            return False

        self.files = files

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
                self._engine.error("Your parameters file must contain a value for plugins_director pointing to the folder containing the ThunderSTORM ImageJ plugin")
                return False

            if "threed" in raw_parameters:
                if raw_parameters["threed"]:
                    self.threed = 1
                else:
                    self.threed = 0
            else:
                self.threed = 0

            if "calibration_file" in raw_parameters:
                self.calibration = raw_parameters["calibration_file"]

        else:
            self._engine.error("No parameters file found - this is a requirement to run the pipeline. JSON properties must include a value for the plugins_directory containing the ThunderSTORM plugin.")
            return False

        return True

    def get_target_file_count(self):
        return self.target_file_count_per_worker

    def get_files(self):
        return self.files

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

    def get_threed(self):
        return self.threed

    def get_calibration(self):
        return self.calibration


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
        super().__init__("CameraGatherer.sh", pipeline)

    def do_before(self, engine):
        self.parameter_string += " -c=" + self.get_pipeline().get_camera()
        self.parameter_string += " -w=" + engine.get_file_system().get_working_directory()

    def map_arguments(self, engine, batch_number):
        # Note this should only be run on one file as we ASSUME that all files use the same camera
        self.parameter_string += " -f=" + self.get_pipeline().get_files()[batch_number]
        return self.parameter_string


class TiffSizeCalculator(PipelineStep):
    def __init__(self, pipeline):
        super().__init__("TiffSizeCalculator.sh", pipeline)

    def map_arguments(self, engine, batch_number):
        self.parameter_string += " -f=" + self.get_pipeline().get_files()[batch_number]
        self.parameter_string += " -t=" + engine.get_file_system().get_working_directory() + os.path.basename(self.get_pipeline().get_files()[batch_number]).replace(".ome.tiff", "_count.txt").replace(".ome.tif", "_count.txt")
        return self.parameter_string

    def do_after(self, engine):
        # Map files to tiff stack size
        for file in self.get_pipeline().get_files():
            source_file = engine.get_file_system().get_working_directory() + os.path.basename(file).replace(".ome.tiff", "_count.txt").replace(".ome.tif", "_count.txt")
            with open(source_file) as f:
                value = int(f.readline())

                # Calculate how many concurrent processes should be acting on this file
                div = value // self.get_pipeline().get_target_file_count()
                rem = value % self.get_pipeline().get_target_file_count()
                if rem > 0:
                    div += 1

                self.get_pipeline().save_size_map(file, value)
                self.get_pipeline().save_batching_map(file, div)
                self.get_pipeline().update_total_batches(div)

        self.get_pipeline().set_file_index(0)
        self.get_pipeline().set_batch_counter(0)


class STORMRunner(PipelineStep):
    def __init__(self, pipeline):
        super().__init__("RunSTORM.sh", pipeline)

    def do_before(self, engine):
        self.parameter_string += " -c=" + self.get_pipeline().get_plugins_directory()
        self.parameter_string += " -s=" + os.path.join(os.path.dirname(os.path.realpath(__file__)), "macros", "localisation.ijm")
        self.parameter_string += " -threed=" + self.get_pipeline().get_threed()

        calib = self.get_pipeline().get_calibration()
        if calib != "":
            self.parameter_string += " -calibration=" + calib

    def map_arguments(self, engine, batch_number):
        file_counter = self.get_pipeline().get_file_index()
        file = self.get_pipeline().get_files()[file_counter]

        start_index = self.get_pipeline().get_batch_counter() + 1
        step_size = self.get_pipeline().get_batching_map_value(file)
        end_index = self.get_pipeline().get_size_map_value(file) + 1

        if start_index == step_size:
            file_counter += 1
            self.get_pipeline().set_file_counter(file_counter)
            self.get_pipeline().set_batch_counter(0)
        else:
            self.get_pipeline().set_batch_counter(start_index)

        parameter_string = self.parameter_string
        parameter_string += " -f=" + file
        parameter_string += " -start=" + str(start_index)
        parameter_string += " -step=" + str(step_size)
        parameter_string += " -end=" + str(end_index)

        return parameter_string


def execute_pipeline(engine):
    engine.info("Welcome to the STORM processing pipeline.")
    pipeline = Pipeline(engine)
    if not pipeline.validate_working_directories():
        engine.error("Failed to validate the working directory.")
        return False

    # Assess the camera manufacturer
    if not engine.submit_and_wait_for_execution(CameraGatherer(pipeline)):
        engine.error("Failed to assess the detector.")
        return False

    # Calculate tiff stack size for each tiff present
    if not engine.submit_chunk_and_wait_for_execution(len(pipeline.files), pipeline.max_concurrent_jobs, TiffSizeCalculator(pipeline)):
        engine.error("Failed to run the tiff stack size calculator")
        return False

    # Loop through our fov's and perform thunderstorm on each
    if not engine.submit_chunk_and_wait_for_execution(pipeline.get_total_batches(), pipeline.max_concurrent_jobs, STORMRunner(pipeline)):
        engine.error("Failed to execute the STORM runner.")
        return False

